//
//  ExplainCodeUseCase.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 15.08.2025.
//

import Foundation
import os.log

/// Use case: generates a plain-text explanation for a single Swift function.
public protocol ExplainCodeUseCase {
    /// Produces an explanation of the given Swift function.
    /// - Parameters:
    ///   - functionSource: Raw Swift source of a single function declaration.
    ///   - promptMaxLength: Maximum number of characters for the prompt after sanitization.
    /// - Returns: Concise plain-text explanation (purpose, inputs/outputs, side effects, errors, edge cases).
    func explainSingleFunction(
        functionSource: String,
        promptMaxLength: Int
    ) async throws -> String
}

/// Default implementation of `ExplainCodeUseCase` backed by an `OllamaBridgeProtocol`.
public struct ExplainCodeUseCaseImpl: ExplainCodeUseCase {
    private let ollama: OllamaBridgeProtocol
    private let config: SwiftMindConfigProtocol

    /// Instruction prompt used as a role model for explanations.
    private let roleModelPromptInstruction: String = """
    You are a Senior iOS Developer who writes clean, maintainable Swift code.
    Follow Apple's coding guidelines and best practices.
    """

    /// Creates an explanation use case.
    public init(ollama: OllamaBridgeProtocol, config: SwiftMindConfigProtocol) {
        self.ollama = ollama
        self.config = config
    }

    public func explainSingleFunction(
        functionSource: String,
        promptMaxLength: Int
    ) async throws -> String {
        let prompt = """
        \(roleModelPromptInstruction)

        Explain the SINGLE Swift function below.

        Output rules (strict):
        - Plain text only (no code blocks, no markdown fences).
        - Be concise but specific.
        - Cover: purpose, inputs/outputs, side effects (I/O, file system), errors thrown, notable edge cases.
        - Mention only what is visible in the function (no assumptions).

        Function:
        \(functionSource)
        """

        let (sanitized, _) = try PromptSanitizer.sanitize(prompt, maxLength: promptMaxLength)
        return try await ollama.send(prompt: sanitized, model: config.defaultModel)
    }
}
