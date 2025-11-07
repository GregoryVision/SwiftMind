import Core
import Foundation
import ArgumentParser
import os.log

/// Entry point for the SwiftMind command-line tool.
///
/// Provides AI-powered utilities for Swift developers, including:
/// - Generating unit tests
/// - Reviewing code
/// - Inserting documentation
/// - Explaining code
/// - Initializing project configuration
///
/// Uses [Swift Argument Parser](https://github.com/apple/swift-argument-parser) for CLI structure.
@main
struct SwiftMindCLI: AsyncParsableCommand {
    
    /// Command-line configuration, including available subcommands.
    static let configuration = CommandConfiguration(
        abstract: "AI CLI for Swift developers",
        subcommands: [Test.self, Review.self, InsertDocs.self, Explain.self, Init.self, Fix.self],
        defaultSubcommand: Explain.self
    )

    /// Global SwiftMind configuration loaded from disk or defaults.
    static let config: SwiftMindConfigProtocol = SwiftMindConfig.load()
    
    /// Shared Ollama bridge instance used for AI communication.
    nonisolated(unsafe) static let ollamaBridge: OllamaBridgeProtocol = OllamaBridge(
        maxRetries: config.maxRetries,
        timeoutSeconds: config.timeoutSeconds
    )

    /// Collection of AI use cases (tests, reviews, explanations, docs).
    nonisolated(unsafe) static let aiUseCases: AIUseCasesProtocol = makeUseCases()
    
    /// Creates all AI use case implementations using the current configuration.
    /// - Returns: An `AIUseCasesProtocol` implementation.
    static func makeUseCases() -> AIUseCasesProtocol {
        let config = SwiftMindConfig.load()
        let ollama = OllamaBridge(maxRetries: config.maxRetries, timeoutSeconds: config.timeoutSeconds)
        return AIUseCases(
            generateTests: GenerateTestsUseCaseImpl(ollama: ollama, config: config),
            reviewCode: ReviewCodeUseCaseImpl(ollama: ollama, config: config),
            explainCode: ExplainCodeUseCaseImpl(ollama: ollama, config: config),
            generateDocs: GenerateDocumentationUseCaseImpl(ollama: ollama, config: config),
            fixCode: FixCodeUseCaseImpl(ollama: ollama, config: config)
        )
    }
}
