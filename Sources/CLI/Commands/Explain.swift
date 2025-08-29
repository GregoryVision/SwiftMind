//
//  ExplainCommand.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 21.07.2025.
//

import Core
import Foundation
import ArgumentParser
import os.log

/// Explains a single Swift function from a given file using AI.
struct Explain: AsyncParsableCommand {
    /// Command configuration shown in `--help`.
    static let configuration = CommandConfiguration(
        abstract: "Explain a SINGLE Swift function from a file"
    )

    /// Subsystem logger for the `Explain` command.
    private static let logger = Logger(subsystem: "SwiftMind", category: "Explain")

    /// Path to the Swift file to analyze.
    @Argument(help: "Path to the Swift file")
    var filePath: String

    /// Target function to explain (name or full signature).
    @Argument(help: "Target function (name or full signature)")
    var function: String

    /// Entry point for the `explain` subcommand.
    func run() async throws {
        print("Starting single-function explanation for: \(filePath) target: \(function)")

        do {
            let codeRes = try CodeProcessingService.prepareCode(from: filePath)

            let collector = FunctionCollector.collect(from: codeRes.sanitizedCode, topLevelOnly: false)
            let matches = collector.functionDecls(target: function)

            guard !matches.isEmpty else {
                throw ValidationError("No function found for target '\(function)'. Try exact name or provide full signature.")
            }
            if matches.count > 1 {
                let options = matches.map { " - \($0.signatureString)" }.joined(separator: "\n")
                throw ValidationError(
                    "Ambiguous target '\(function)'. Found multiple overloads:\n\(options)\nProvide the full signature to disambiguate."
                )
            }

            guard let fn = matches.first else {
                throw ValidationError("Internal error: unexpected empty match list.")
            }

            let functionSource = String(fn.description)
            let signature = fn.signatureString

            let raw = try await SwiftMindCLI.aiUseCases.explainCode.explainSingleFunction(
                functionSource: functionSource,
                promptMaxLength: SwiftMindCLI.config.promptMaxLength
            )

            let explanation = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !explanation.isEmpty else {
                throw ValidationError("Explanation is empty. Try adjusting the function target or prompt length.")
            }

            print("📝 Explanation for: \(signature)\n")
            print(explanation)

        } catch {
            try SwiftMindError.handle(error)
        }
    }
}
