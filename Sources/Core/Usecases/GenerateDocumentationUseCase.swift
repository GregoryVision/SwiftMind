//
//  GenerateDocumentationUseCase.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 15.08.2025.
//

import Foundation
import os.log

public protocol GenerateDocumentationUseCase {
    func generateSingleFunctionDoc(functionSource: String,
                                          style: DocumentationStyle,
                                          promptMaxLength: Int) async throws -> String
}

public struct GenerateDocumentationUseCaseImpl: GenerateDocumentationUseCase {
    private let ollama: OllamaBridgeProtocol
    private let config: SwiftMindConfigProtocol

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

    public func generateSingleFunctionDoc(functionSource: String,
                                          style: DocumentationStyle,
                                          promptMaxLength: Int) async throws -> String {
        let styleInstruction: String = switch style {
        case .brief:   "Write concise, summary focusing on what the function does. Limit: 3-4 lines"
        case .detailed:"Write detailed documentation including parameters, return value"
        }
        
        let prompt = """
            \(roleModelPromptInstruction)
            
            Generate Swift documentation comment for the following single function ONLY.
            
            Output rules:
            - Return ONLY plain text of the doc comment (no code fences, no /// prefixes).
            - Do NOT include the original code
            - Do NOT use block comments (`/** ... */`).
            - Use Xcode Quick Help sections.
            - Include sections only when applicable.
            
            Example:
            Brief description what function does
            
            - Parameter name: Description
            - Returns: Description
            - Throws: Error conditions
            
            Documentation style: \(styleInstruction)
            
            Function:
            \(functionSource)
            """
        
        let (sanitized, _) = try PromptSanitizer.sanitize(prompt, maxLength: promptMaxLength)
        return try await ollama.send(prompt: sanitized, model: config.defaultModel)
    }
}
