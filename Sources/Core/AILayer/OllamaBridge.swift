//
//  OllamaBridge.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 06.06.2025.
//

import Foundation
import os.log

/// A minimal transport to the local Ollama CLI.
public protocol OllamaBridgeProtocol {
    /// Sends a prompt to a specific model and returns raw model output as a `String`.
    /// - Parameters:
    ///   - prompt: Full prompt text (already sanitized by the caller).
    ///   - model: Model name/tag understood by the Ollama CLI.
    func send(prompt: String, model: String) async throws -> String
}

/// Concrete Ollama bridge that shells out to the `ollama` CLI and handles retries/timeouts.
///
/// Notes:
/// - Uses a child `Process` to run `ollama run <model>`.
/// - Protects the child process with a lock so it can be cancelled on timeout.
/// - Marked `@unchecked Sendable` because `Process` and `NSLock` are not strictly Sendable.
public final class OllamaBridge: OllamaBridgeProtocol, @unchecked Sendable {

    private let logger = Logger(subsystem: "SwiftMind", category: "OllamaBridge")
    private let maxRetries: Int
    private let timeoutSeconds: Double

    // Current child process (for cancellation/timeout)
    private var currentProcess: Process?
    private let processLock = NSLock()

    /// - Parameters:
    ///   - maxRetries: Number of retry attempts on failures.
    ///   - timeoutSeconds: Overall timeout for a single `ollama run` invocation.
    public init(maxRetries: Int = 3, timeoutSeconds: Double = 60) {
        self.maxRetries = maxRetries
        self.timeoutSeconds = timeoutSeconds
    }

    // MARK: - Public

    /// Sends a prompt to Ollama and returns the raw model output.
    ///
    /// Performs:
    /// 1) CLI presence check, 2) model existence check, 3) execution with retry + exponential backoff,
    /// 4) a race between execution and a timeout task, and 5) graceful cancellation on timeout.
    public func send(prompt: String, model: String = "codellama") async throws -> String {
        try await validateOllamaInstallation()
        try await ensureModelExists(model)

        logger.info("Sending prompt to Ollama (model: \(model, privacy: .public), length: \(prompt.count, privacy: .public))")

        let progress = ProgressIndicator()
        await progress.start("Generating response with AI...")
        defer { Task { await progress.stop() } }

        var lastError: Error?

        for attempt in 1...maxRetries {
            do {
                let result = try await executeOllama(prompt: prompt, model: model)
                logger.info("Successfully received response from Ollama")
                return result
            } catch {
                lastError = error
                logger.warning("Attempt \(attempt) failed: \(error.localizedDescription, privacy: .public)")

                if attempt < maxRetries {
                    // Exponential backoff + jitter
                    let backoff = min(8.0, pow(2.0, Double(attempt - 1))) // 1, 2, 4, 8
                    let jitter = Double.random(in: 0...0.5)
                    let sleepSec = backoff + jitter
                    logger.info("Retrying in \(sleepSec, privacy: .public)s...")
                    try await Task.sleep(nanoseconds: UInt64(sleepSec * 1_000_000_000))
                }
            }
        }

        throw lastError ?? SwiftMindError.ollamaExecutionFailed(-1, "Unknown error after retries")
    }

    // MARK: - Validation

    /// Ensures the `ollama` CLI is available by invoking `ollama --version`.
    private func validateOllamaInstallation() async throws {
        _ = try await runQuick(["ollama", "--version"])
    }

    /// Ensures the requested model exists locally by invoking `ollama show <model>`.
    private func ensureModelExists(_ model: String) async throws {
        do {
            _ = try await runQuick(["ollama", "show", model])
        } catch {
            throw SwiftMindError.modelMissing(model)
        }
    }

    // MARK: - Timeout race

    /// Runs the model with a timeout race: whichever finishes first (run or timeout) wins.
    private func executeOllama(prompt: String, model: String) async throws -> String {
        try await withThrowingTaskGroup(of: String.self) { group in
            let bridge = self  // strong ref while tasks run
            group.addTask {
                try await bridge.runOllama(prompt: prompt, model: model)
            }
            group.addTask { [timeoutSeconds] in
                try await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                throw SwiftMindError.timeout(timeoutSeconds)
            }

            defer { group.cancelAll() } // ensure the loser is cancelled

            guard let first = try await group.next() else {
                throw SwiftMindError.ollamaExecutionFailed(-1, "Task group returned no result")
            }
            return first
        }
    }

    // MARK: - Core execution (stdin + background readers + cancellation)

    /// Spawns `ollama run` and streams stdout/stderr. Supports cancellation via `withTaskCancellationHandler`.
    private func runOllama(prompt: String, model: String) async throws -> String {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                task.arguments = ["ollama", "run", model]

                // stdin — write prompt
                let stdin = Pipe()
                task.standardInput = stdin

                // stdout/stderr — read in background tasks (no readabilityHandler)
                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                task.standardOutput = stdoutPipe
                task.standardError = stderrPipe

                let stdoutFH = stdoutPipe.fileHandleForReading
                let stderrFH = stderrPipe.fileHandleForReading

                // Background reads (each into a local buffer)
                let outTask = Task.detached(priority: .utility) { () -> Data in
                    var buf = Data()
                    while true {
                        let chunk = stdoutFH.availableData
                        if chunk.isEmpty { break } // EOF
                        buf.append(chunk)
                    }
                    return buf
                }

                let errTask = Task.detached(priority: .utility) { () -> Data in
                    var buf = Data()
                    while true {
                        let chunk = stderrFH.availableData
                        if chunk.isEmpty { break } // EOF
                        buf.append(chunk)
                    }
                    return buf
                }

                task.terminationHandler = { [weak self] process in
                    // Completion: close handles, await background readers, assemble output
                    stdoutFH.closeFile()
                    stderrFH.closeFile()

                    Task {
                        let outData = await outTask.value
                        let errData = await errTask.value

                        let out = String(decoding: outData, as: UTF8.self)
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        let err = String(decoding: errData, as: UTF8.self)
                            .trimmingCharacters(in: .whitespacesAndNewlines)

                        self?.setCurrentProcess(nil)

                        if process.terminationStatus == 0 {
                            cont.resume(returning: out)
                        } else {
                            cont.resume(throwing: SwiftMindError.ollamaExecutionFailed(
                                process.terminationStatus,
                                err.isEmpty ? "Unknown error" : err
                            ))
                        }
                    }
                }

                do {
                    try task.run()
                    self.setCurrentProcess(task)

                    // Write prompt then close stdin
                    if let data = prompt.data(using: .utf8) {
                        stdin.fileHandleForWriting.write(data)
                    }
                    stdin.fileHandleForWriting.closeFile()

                } catch {
                    self.setCurrentProcess(nil)
                    cont.resume(throwing: error)
                }
            }
        } onCancel: {
            // Cancellation/timeout: try to terminate gracefully, then SIGKILL
            guard let proc = getCurrentProcess() else { return }
            logger.warning("Cancelling ollama process...")
            if proc.isRunning {
                proc.terminate()
                DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                    if proc.isRunning {
                        Darwin.kill(proc.processIdentifier, SIGKILL)
                    }
                }
            }
            setCurrentProcess(nil)
        }
    }

    // MARK: - Helpers

    /// Runs a short synchronous command and returns stdout (throws on non-zero exit).
    @discardableResult
    private func runQuick(_ args: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { cont in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            p.arguments = args

            let out = Pipe()
            let err = Pipe()
            p.standardOutput = out
            p.standardError = err

            p.terminationHandler = { process in
                let outData = out.fileHandleForReading.readDataToEndOfFile()
                let errData = err.fileHandleForReading.readDataToEndOfFile()
                let stdout = String(decoding: outData, as: UTF8.self)
                let stderr = String(decoding: errData, as: UTF8.self)

                if process.terminationStatus == 0 {
                    cont.resume(returning: stdout)
                } else {
                    cont.resume(throwing: SwiftMindError.ollamaExecutionFailed(
                        process.terminationStatus,
                        stderr.isEmpty ? "Unknown error" : stderr
                    ))
                }
            }

            do {
                try p.run()
            } catch {
                cont.resume(throwing: error)
            }
        }
    }

    /// Stores the current child `Process` under lock.
    private func setCurrentProcess(_ p: Process?) {
        processLock.lock()
        currentProcess = p
        processLock.unlock()
    }

    /// Reads the current child `Process` under lock.
    private func getCurrentProcess() -> Process? {
        processLock.lock()
        let p = currentProcess
        processLock.unlock()
        return p
    }
}
