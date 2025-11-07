//
//  FixCommand.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 13.08.2025.
//

import ArgumentParser
import os.log
import SwiftSyntax
import SwiftParser
import Core

struct Fix: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "AI-assisted fixes for Swift functions (cleanliness, memory, threading, error handling)."
    )
    private static let logger = Logger(subsystem: "SwiftMind", category: "Fix")

    @Argument(help: "Path to the Swift file to fix")
    var filePath: String

    @Argument(help: "Target function names or full signatures (processes in order). If empty — all functions.")
    var functions: [String] = []

    @Flag(name: .long, help: "Apply fixes to the source file in place")
    var apply: Bool = false

    @Option(name: .long, help: "Optional high-level goals, e.g. 'avoid retain cycles; enforce main-thread UI; better error handling'")
    var goals: String?

    func run() async throws {
        do {
            Self.logger.info("Starting fixes for: \(filePath)")
            
            let cfg = SwiftMindCLI.config
            let codeRes = try CodeProcessingService.prepareCode(from: filePath)
            let code = codeRes.sanitizedCode
            let collector = FunctionCollector.collect(from: code, topLevelOnly: false)

            let targetNodes: [FunctionDeclSyntax] = {
                if functions.isEmpty { return collector.functions }
                return functions.flatMap { collector.functionDecls(target: $0) }
            }()

            guard !targetNodes.isEmpty else {
                Self.logger.warning("No matching functions found.")
                return
            }

            var replacements: [String: String] = [:] // signature -> fixedFunctionSource
            for fn in targetNodes {
                let sig = fn.signatureString
                let functionSource = String(fn.description)

                Self.logger.info("AI fixing: \(sig, privacy: .public)")
                let fixed = try await SwiftMindCLI.aiUseCases.fixCode.fixSingleFunction(
                    functionSource: functionSource,
                    goals: goals,
                    promptMaxLength: cfg.promptMaxLength
                )
                
                print(fixed)
                

                let trimmed = fixed.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty || trimmed == "__NO_CHANGE__" {
                    print("No changes for: \(sig)")
                    continue
                }

                // Быстрый «идемпотентный» чек: если совпадает с исходником — тоже пропускаем
                if normalized(functionSource) == normalized(trimmed) {
                    Self.logger.info("Identical code for: \(sig, privacy: .public)")
                    continue
                }

                if apply {
                    replacements[sig] = trimmed
                } else {
                    // Только печать результата
                    print("🛠️ Fixed \(sig):\n")
                    print(trimmed)
                    print("\n" + String(repeating: "—", count: 60) + "\n")
                }
            }
            
            // 5) Применить патчи (по сигнатурам)
            if apply && !replacements.isEmpty {
                let (processed, skipped) = try FunctionPatchRewriter.apply(
                    to: code,
                    replacementsBySignature: replacements,
                    writeTo: codeRes.resolvedFileURL
                )
                Self.logger.info("Applied: processed=\(processed), skipped=\(skipped)")
            }
        } catch {
            try SwiftMindError.handle(error)
        }
    }
}

private func normalized(_ s: String) -> String {
    s.replacingOccurrences(of: "\r\n", with: "\n")
     .replacingOccurrences(of: "\r", with: "\n")
     .trimmingCharacters(in: .whitespacesAndNewlines)
}

