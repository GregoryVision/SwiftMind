//
//  GenerateDocumentationUseCase.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 15.08.2025.
//

import Foundation
import os.log

public protocol GenerateDocumentationUseCase {
    func generateBlocks(for code: String,
                        style: DocumentationStyle,
                        declarations: [String]) async throws -> [String]

    func generateFullCode(for code: String,
                          style: DocumentationStyle,
                          declarations: [String]) async throws -> String
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

    public func generateBlocks(for code: String,
                                style: DocumentationStyle,
                                declarations: [String]) async throws -> [String] {
        let result = try await generateInternal(for: code,
                                                style: style,
                                                declarations: declarations,
                                                returnFormat: .separateBlocks)
        return result
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    public func generateFullCode(for code: String,
                                 style: DocumentationStyle,
                                 declarations: [String]) async throws -> String {
        return try await generateInternal(for: code,
                                          style: style,
                                          declarations: declarations,
                                          returnFormat: .fullCode)
    }

    private func generateInternal(for code: String,
                                  style: DocumentationStyle,
                                  declarations: [String],
                                  returnFormat: DocumentationReturnFormat) async throws -> String {
        let styleInstruction = switch style {
        case .brief:
            "Write concise, single-line documentation focusing on what the element does."
        case .detailed:
            "Write detailed documentation including parameters, return values, and usage examples where appropriate."
        }

        let formatInstruction = switch returnFormat {
        case .separateBlocks:
            """
            Output format:
            - Each documentation block should be plain text (no /// prefixes)
            - Separate each documentation block with exactly TWO newlines (\\n\\n)
            - Do NOT include the original code in your response
            """
        case .fullCode:
            """
            Output format:
            - Return the modified Swift source code with the generated documentation comments (///) directly inserted
            - Do NOT return the original unmodified code
            - Do NOT wrap the response in markdown or any additional formatting
            """
        }

        let formattedDeclarations = declarations.map { "- \($0)" }.joined(separator: "\n")

        let prompt = """
        \(roleModelPromptInstruction)

        Generate Swift documentation comments for the following code. Follow these rules EXACTLY:

        1. Generate documentation ONLY for these declaration types:
           \(formattedDeclarations)

        2. Process declarations in the EXACT order they appear in the source code

        3. Generate documentation for ALL declarations of the above types, regardless of access level

        4. \(formatInstruction)

        5. Documentation style: \(styleInstruction)

        6. For functions with parameters, include @param documentation
        7. For functions with return values, include @return documentation

        Swift code to document:

        \(code)
        """

        return try await ollama.send(prompt: prompt, model: config.defaultModel)
    }
}
