//
//  ExplainCodeUseCase.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 15.08.2025.
//

import Foundation
import os.log

public protocol ExplainCodeUseCase {
    func explainSingleFunction(functionSource: String,
                               promptMaxLength: Int) async throws -> String
}

public struct ExplainCodeUseCaseImpl: ExplainCodeUseCase {
    private let ollama: OllamaBridgeProtocol
    private let config: SwiftMindConfigProtocol

    private var roleModelPromptInstruction: String {
        """
        You are a Senior iOS Developer who writes clean, maintainable Swift code.
        Follow Apple's coding guidelines and best practices.
        """
    }

    public init(ollama: OllamaBridgeProtocol, config: SwiftMindConfigProtocol) {
        self.ollama = ollama
        self.config = config
    }

    public func explainSingleFunction(functionSource: String,
                                      promptMaxLength: Int) async throws -> String {
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
