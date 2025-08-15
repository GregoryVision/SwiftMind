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
                     functionName: String,
                     customPrompt: String?,
                     additionalContext: String?) async throws -> String

    func forEntireFile(code: String,
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
        Follow Apple's coding guidelines and best practices.
        """
    }

    public init(ollama: OllamaBridgeProtocol, config: SwiftMindConfigProtocol) {
        self.ollama = ollama
        self.config = config
    }

    public func forFunction(code: String,
                            functionName: String,
                            customPrompt: String?,
                            additionalContext: String?) async throws -> String {
        logger.info("Generating tests for function: \(functionName)")

        let fileHeader = """
        This file contains the following Swift function:

        \(code)
        """

        let testInstruction = """
        Write unit tests for the function named "\(functionName)" using XCTest.  
        Each test should be independent and cover typical use cases and edge cases.  
        Use descriptive test method names that reflect behavior being tested.
        If the function is asynchronous, use `XCTestExpectation` or `async/await`.
        """

        let addCtx = additionalContext.flatMap {
            """
            This is additional context:

            \($0)
            """
        }

        let cusPrompt = customPrompt.flatMap {
            """
            This is custom prompt from user:

            \($0)
            """
        }

        let prompt = [fileHeader, roleModelPromptInstruction, testInstruction, addCtx, cusPrompt]
            .compactMap { $0 }
            .joined(separator: "\n\n")

        return try await ollama.send(prompt: prompt, model: config.defaultModel)
    }

    public func forEntireFile(code: String,
                              customPrompt: String?,
                              additionalContext: String?) async throws -> String {
        logger.info("Generating tests for entire file")

        let fileHeader = """
        Generate a complete Swift unit test file for the following source code:

        \(code)
        """

        let addCtx = additionalContext.flatMap {
            """
            This is additional context:

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

        let prompt = [fileHeader, roleModelPromptInstruction, addCtx, cusPrompt]
            .compactMap { $0 }
            .joined(separator: "\n\n")

        return try await ollama.send(prompt: prompt, model: config.defaultModel)
    }
}
