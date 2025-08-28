import Core
import Foundation
import ArgumentParser
import os.log

import SwiftSyntax
import SwiftParser

@main
struct SwiftMindCLI: AsyncParsableCommand {
    
    static let configuration = CommandConfiguration(
        abstract: "AI CLI for Swift developers",
        subcommands: [Test.self, Review.self, InsertDocs.self, Explain.self, Init.self],
        defaultSubcommand: Explain.self
    )
    static let config: SwiftMindConfigProtocol = SwiftMindConfig.load()
    nonisolated(unsafe) static let ollamaBridge: OllamaBridgeProtocol = OllamaBridge(maxRetries: config.maxRetries, timeoutSeconds: config.timeoutSeconds)
    nonisolated(unsafe) static let aiUseCases: AIUseCasesProtocol = makeUseCases()
    
    static func makeUseCases() -> AIUseCasesProtocol {
        let config = SwiftMindConfig.load()
        let ollama = OllamaBridge(maxRetries: config.maxRetries, timeoutSeconds: config.timeoutSeconds)
        return AIUseCases(
            generateTests: GenerateTestsUseCaseImpl(ollama: ollama, config: config),
            reviewCode: ReviewCodeUseCaseImpl(ollama: ollama, config: config),
            explainCode: ExplainCodeUseCaseImpl(ollama: ollama, config: config),
            generateDocs: GenerateDocumentationUseCaseImpl(ollama: ollama, config: config)
        )
    }
}
