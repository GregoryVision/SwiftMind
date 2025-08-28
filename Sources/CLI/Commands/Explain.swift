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

@available(macOS 13.0, *)
struct Explain: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Explain a SINGLE Swift function from a file"
    )

    private static let logger = Logger(subsystem: "SwiftMind", category: "Explain")

    @Argument(help: "Path to the Swift file")
    var filePath: String

    @Argument(help: "Target function (name or full signature)")
    var function: String

    func run() async throws {
        print("Starting single-function explanation for: \(filePath) target: \(function)")

        do {
            let codeRes = try CodeProcessingService.prepareCode(from: filePath)

            let collector = FunctionCollector.collect(from: codeRes.sanitizedCode, topLevelOnly: false)
            let matches = collector.functionDecls(target: function)

            guard !matches.isEmpty else {
                throw ValidationError("No function found for target '\(function)'. Try exact name or full signature.")
            }
            if matches.count > 1 {
                let options = matches.map { " - \($0.signatureString)" }.joined(separator: "\n")
                throw ValidationError("Ambiguous target '\(function)'. Found multiple overloads:\n\(options)\nProvide full signature to disambiguate.")
            }

            let fn = matches[0]
            let functionSource = String(fn.description)
            let signature = fn.signatureString

            let explanation = try await SwiftMindCLI.aiUseCases.explainCode.explainSingleFunction(
                functionSource: functionSource,
                promptMaxLength: SwiftMindCLI.config.promptMaxLength
            )

            print("📝 Explanation for: \(signature)\n")
            print(explanation)

        } catch {
            try SwiftMindError.handle(error)
        }
    }
}
