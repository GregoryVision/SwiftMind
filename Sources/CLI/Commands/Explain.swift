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
    
    static let configuration = CommandConfiguration(abstract: "Explain what Swift code does")
    private static let logger = Logger(subsystem: "SwiftMind", category: "Review")
    
    @Argument(help: "The file to explain")
    var filePath: String
    
    func run() async throws {
        Self.logger.info("Starting code explaining for: \(filePath)")
        
        do {
            let (_, _, code) = try CodeProcessingService.prepareCode(from: filePath,
                                                             promptMaxLength: SwiftMindCLI.config.promptMaxLength)
            let explanation = try await generateExplanation(for: code, cfg: SwiftMindCLI.config)
            printExplanation(explanation)
        } catch {
            try SwiftMindError.handle(error, logger: Self.logger)
        }
    }
    
    private func generateExplanation(for code: String, cfg: SwiftMindConfigProtocol) async throws -> String {
        return try await SwiftMindCLI.aiUseCases.explainCode.explain(code: code)
    }
    
    private func printExplanation(_ explanation: String) {
        print("📝 Code Explanation:")
        print(explanation)
    }
}
