//
//  GenerateTestsUseCase.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 15.08.2025.
//

import Foundation
import os.log

public protocol GenerateTestsUseCase {
    func forFunction(code: String,
                     funcName: String,
                     funcSign: String,
                     promptMaxLength: Int,
                     customPrompt: String?) async throws -> String

    func forEntireFile(code: String,
                       promptMaxLength: Int,
                       customPrompt: String?,
                       additionalContext: String?) async throws -> String
}

public struct GenerateTestsUseCaseImpl: GenerateTestsUseCase {
    private let ollama: OllamaBridgeProtocol
    private let config: SwiftMindConfigProtocol
    private let logger = Logger(subsystem: "SwiftMind", category: "GenerateTests")
    
    private var roleModelPromptInstruction: String {
        """
        You are a Senior iOS Developer who writes clean, maintainable Swift code.
        You must output only valid Swift XCTest code. Never explain or add comments.
        """
    }
    
    private var commonTestGuidelines: String {
    """
    Write unit tests using XCTest.

    STRICT OUTPUT:
    - Output ONLY valid Swift test code. No Markdown, no prose.
    - Test ONLY the specified function/type.

    RULES:
    - Do NOT invent new methods/types/initializers/error cases.
    - Do NOT call functions with missing/extra params; respect existing signatures.
    - Do NOT change access modifiers or code structure.
    - Do NOT add @testable import.
    - Prefer behavior-based tests; include edge cases and at least one negative case.
    - Use XCTestExpectation or async/await for async code.
    - Use XCTAssertThrowsError for throwing paths.
    """
    }

    public init(ollama: OllamaBridgeProtocol, config: SwiftMindConfigProtocol) {
        self.ollama = ollama
        self.config = config
    }

    public func forFunction(code: String,
                            funcName: String,
                            funcSign: String,
                            promptMaxLength: Int,
                            customPrompt: String?) async throws -> String {
        logger.info("Generating tests for function: \(funcName)")

        let taskInstruction = """
        Write unit tests for the function with signature: "\(funcSign)".
        Start with: class \(funcName)Tests: XCTestCase {
        """

        let cusPrompt = customPrompt.flatMap {
            """
            This is custom prompt from user:

            \($0)
            """
        }

        let prompt = [roleModelPromptInstruction,
                      commonTestGuidelines,
                      taskInstruction,
                      "Source code:\n\n\(code)",
                      cusPrompt]
            .compactMap { $0 }
            .joined(separator: "\n\n")
        
        let (sanitizedPrompt, _) = try PromptSanitizer.sanitize(prompt, maxLength: promptMaxLength)
        
        return try await ollama.send(prompt: sanitizedPrompt, model: config.defaultModel)
    }

    public func forEntireFile(code: String,
                              promptMaxLength: Int,
                              customPrompt: String?,
                              additionalContext: String?) async throws -> String {
        logger.info("Generating tests for entire file")

        let taskInstruction = """
        Generate a test class named <OriginalTypeName>Tests for the provided Source code.

        Rules:
        - Identify the main class or struct in the source code.
        - Generate XCTest test cases for its public functions and methods.
        - Cover normal behavior, edge cases, and at least one failure case if applicable.

        STRICT OUTPUT RULES:
        - Output ONLY valid Swift XCTest code.
        - Start immediately with: class <OriginalTypeName>Tests: XCTestCase {
        - Do NOT include imports, comments, explanations, or markdown fences.
        """

        let addCtx = additionalContext.flatMap {
            """
            "ADDITIONAL CONTEXT (STRICT RULES):
            - Use ONLY for understanding environment.
            - NEVER generate tests for this section.
            - Tests must be generated ONLY for the main provided source file."

            \($0)
            """
        }

        let cusPrompt = customPrompt.flatMap {
            """
            This is custom prompt from user:

            \($0)

            Use XCTest, avoid redundant tests, and ensure good naming conventions.
            """
        }
        
        let prompt = [addCtx,
                      "Source code:\n\n\(code)",
                      cusPrompt,
                      roleModelPromptInstruction,
                      commonTestGuidelines,
                      taskInstruction]
            .compactMap { $0 }
            .joined(separator: "\n\n")
        
        let (sanitizedPrompt, _) = try PromptSanitizer.sanitize(prompt, maxLength: promptMaxLength)
        return try await ollama.send(prompt: sanitizedPrompt, model: config.defaultModel)
    }
}
