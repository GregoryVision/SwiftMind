//
//  GenerateDocumentationUseCase.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 15.08.2025.
//

import Foundation
import os.log

/// Use case: generates Xcode-style documentation comments (`///`) for a single Swift function.
public protocol GenerateDocumentationUseCase {
    /// Produces documentation text for a given Swift function.
    ///
    /// - Parameters:
    ///   - functionSource: Raw Swift source of a single function declaration.
    ///   - style: Desired documentation style (brief/detailed).
    ///   - promptMaxLength: Maximum number of characters for the prompt after sanitization.
    /// - Returns: Plain-text documentation (without `///` prefixes, code fences, or block comments).
    func generateSingleFunctionDoc(
        functionSource: String,
        style: DocumentationStyle,
        promptMaxLength: Int
    ) async throws -> String
}

/// Default implementation of `GenerateDocumentationUseCase` backed by an `OllamaBridgeProtocol`.
public struct GenerateDocumentationUseCaseImpl: GenerateDocumentationUseCase {
    private let ollama: OllamaBridgeProtocol
    private let config: SwiftMindConfigProtocol

    /// Instruction prompt used as a role model for generated docs.
    private let roleModelPromptInstruction: String = """
    You are a Senior iOS Developer who writes clean, maintainable Swift code.
    Follow Apple's coding guidelines and best practices.
    """

    /// Creates a documentation generation use case.
    public init(ollama: OllamaBridgeProtocol, config: SwiftMindConfigProtocol) {
        self.ollama = ollama
        self.config = config
    }

    public func generateSingleFunctionDoc(
        functionSource: String,
        style: DocumentationStyle,
        promptMaxLength: Int
    ) async throws -> String {
        let styleInstruction: String = switch style {
        case .brief:
            "Write concise summary focusing on what the function does. Limit: 3–4 lines."
        case .detailed:
            "Write detailed documentation including parameters and return value."
        }
        
        let prompt = """
        \(roleModelPromptInstruction)
        
        Generate Swift documentation comment for the following single function ONLY.
        
        Output rules:
        - Return ONLY plain text of the doc comment (no code fences, no /// prefixes).
        - Do NOT include the original code.
        - Do NOT use block comments (`/** ... */`).
        - Use Xcode Quick Help sections.
        - Include sections only when applicable.
        
        Example:
        Brief description of what the function does.
        
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
