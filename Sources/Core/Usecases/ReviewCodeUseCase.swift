//
//  ReviewCodeUseCase.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 15.08.2025.
//

import Foundation
import os.log

public protocol ReviewCodeUseCase {
    func generateSingleFunctionReview(functionSource: String,
                                      functionSignature: String,
                                      promptMaxLength: Int) async throws -> String
}

public struct ReviewCodeUseCaseImpl: ReviewCodeUseCase {
    private let ollama: OllamaBridgeProtocol
    private let config: SwiftMindConfigProtocol
    private let logger = Logger(subsystem: "SwiftMind", category: "ReviewCode")

    public init(ollama: OllamaBridgeProtocol, config: SwiftMindConfigProtocol) {
        self.ollama = ollama
        self.config = config
    }

    private var roleModelPromptInstruction: String {
        """
        You are a Senior iOS Developer who writes clean, maintainable Swift code.
        Follow Apple's coding guidelines and best practices.
        """
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
