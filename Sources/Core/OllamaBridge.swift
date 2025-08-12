//
//  OllamaBridge.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 06.06.2025.
//

import Foundation
import os.log

@available(macOS 13.0, *)
public protocol OllamaBridgeProtocol {
    func send(prompt: String, model: String) async throws -> String
}

@available(macOS 13.0, *)
public final class OllamaBridge: OllamaBridgeProtocol, @unchecked Sendable {
    
    private let logger = Logger(subsystem: "SwiftMind", category: "OllamaBridge")
    private let maxRetries: Int
    private let timeoutSeconds: Double
    
    public init(maxRetries: Int,
                timeoutSeconds: Double) {
        
        self.maxRetries = maxRetries
        self.timeoutSeconds = timeoutSeconds
    }
    
    // MARK: - Core Send Method
    public func send(prompt: String, model: String = "codellama") async throws -> String {
        try await validateOllamaInstallation()
        
        logger.info("Sending prompt to Ollama (model: \(model), length: \(prompt.count))")
        
        let progress = ProgressIndicator()
        await progress.start(message: "Generating response with AI...")
        
        defer {
            Task { await progress.stop() }
        }
        
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                let result = try await executeOllama(prompt: prompt, model: model)
                await progress.stop()
                logger.info("Successfully received response from Ollama")
                return result
            } catch {
                lastError = error
                logger.warning("Attempt \(attempt) failed: \(error.localizedDescription)")
                logger.info("Retrying in \(attempt) second(s)...")
                try await Task.sleep(nanoseconds: UInt64(attempt * 1_000_000_000))
            }
        }
        
        throw lastError ?? SwiftMindError.ollamaExecutionFailed(-1, "Unknown error")
    }
    
    // MARK: - Validation
    private func validateOllamaInstallation() async throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        task.arguments = ["ollama"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus != 0 {
                throw SwiftMindError.ollamaNotInstalled
            }
        } catch {
            logger.error("Failed to validate Ollama installation: \(error.localizedDescription)")
            throw SwiftMindError.ollamaNotInstalled
        }
    }
    
    private func executeOllama(prompt: String, model: String) async throws -> String {
        try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask {
                return try await self.runOllama(prompt: prompt, model: model)
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(self.timeoutSeconds * 1_000_000_000))
                throw SwiftMindError.ollamaExecutionFailed(-1, "Timeout after \(self.timeoutSeconds) seconds")
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
    
    private func runOllama(prompt: String, model: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            task.arguments = ["ollama", "run", model, prompt]
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            task.standardOutput = outputPipe
            task.standardError = errorPipe
            
            task.terminationHandler = { process in
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                
                let output = String(decoding: outputData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                let errorOutput = String(decoding: errorData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                
                if process.terminationStatus == 0 {
                    continuation.resume(returning: output)
                } else {
                    let error = errorOutput.isEmpty ? "Unknown error" : errorOutput
                    continuation.resume(throwing: SwiftMindError.ollamaExecutionFailed(process.terminationStatus, error))
                }
            }
            
            do {
                try task.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
