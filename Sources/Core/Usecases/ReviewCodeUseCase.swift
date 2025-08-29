//
//  ReviewCodeUseCase.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 15.08.2025.
//

import Foundation
import os.log

/// Use case: generates a concise, plain-text code review for a single Swift function.
public protocol ReviewCodeUseCase {
    /// Produces a focused review of a single function.
    /// - Parameters:
    ///   - functionSource: Raw Swift source of the function declaration and body.
    ///   - functionSignature: Canonical signature string used for context.
    ///   - promptMaxLength: Maximum allowed length after prompt sanitization.
    /// - Returns: Plain-text review; if there are no issues, a short positive sentence.
    func generateSingleFunctionReview(
        functionSource: String,
        functionSignature: String,
        promptMaxLength: Int
    ) async throws -> String
}

/// Default implementation of `ReviewCodeUseCase` backed by an `OllamaBridgeProtocol`.
public struct ReviewCodeUseCaseImpl: ReviewCodeUseCase {
    private let ollama: OllamaBridgeProtocol
    private let config: SwiftMindConfigProtocol

    /// Instruction prompt used as a role model for reviews.
    private let roleModelPromptInstruction: String = """
    You are a Senior iOS Developer who writes clean, maintainable Swift code.
    Follow Apple's coding guidelines and best practices.
    """

    /// Creates a code-review use case.
    public init(ollama: OllamaBridgeProtocol, config: SwiftMindConfigProtocol) {
        self.ollama = ollama
        self.config = config
    }

    public func generateSingleFunctionReview(
        functionSource: String,
        functionSignature: String,
        promptMaxLength: Int
    ) async throws -> String {

        let prompt = """
        \(roleModelPromptInstruction)

        Do a focused code review of the SINGLE Swift function.

        Strict:
        - Plain text only. No code, no fences, no headings, no prefixes.
        - Mention ONLY things present in the function (no assumptions).
        - If no issues: output ONE short positive sentence.

        Focus: correctness, safety, performance, API design, readability, Swift best practices.

        Function signature:
        \(functionSignature)

        Function source:
        \(functionSource)
        """

        let (sanitized, _) = try PromptSanitizer.sanitize(prompt, maxLength: promptMaxLength)
        return try await ollama.send(prompt: sanitized, model: config.defaultModel)
    }
}
