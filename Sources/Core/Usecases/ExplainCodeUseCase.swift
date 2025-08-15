//
//  ExplainCodeUseCase.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 15.08.2025.
//

import Foundation
import os.log

public protocol ExplainCodeUseCase {
    func explain(code: String) async throws -> String
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

    public func explain(code: String) async throws -> String {
        let prompt = """
        \(roleModelPromptInstruction)

        Analyze and explain the following Swift code. Provide a detailed yet concise explanation covering:
        1. The main purpose and functionality of the code.
        2. Key functions, classes, or structs and what they do.
        3. Important parameters or return values.
        4. Any potential issues, best practices, or improvements.

        Swift code:
        \(code)
        """
        return try await ollama.send(prompt: prompt, model: config.defaultModel)
    }
}
