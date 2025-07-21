//
//  AIUseCases.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 06.06.2025.
//

import Foundation
import os.log

public struct AIUseCases {
    
    private static let logger = Logger(subsystem: "SwiftMind", category: "AIUseCases")
    
    public static func generateReadme(from source: String) throws -> String {
        return """
        # Auto-generated README
        
        Documentation for Swift file:
        
        ```swift
        \(source)
        ```
        """
    }
    public static func generateTests(for code: String, functionName: String, customPrompt: String? = nil, additionalContext: String? = nil) async throws -> String {
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
        
        var addCtx: String? = additionalContext
        
        if let additionalContext {
            addCtx = """
        This is additional context:
        
        \(additionalContext)
        """
        }
        
        var cusPrompt: String? = customPrompt
        
        if let customPrompt {
            cusPrompt = """
        This is custom prompt from user:
        
        \(customPrompt)
        """
        }
        
        let prompt = [fileHeader, testInstruction, addCtx, cusPrompt].compactMap { $0 }.joined(separator: "\n\n")
        
        return try await OllamaBridge.shared.send(prompt: prompt)
    }
    
    public static func generateTestsForEntireFile(_ code: String, customPrompt: String? = nil, additionalContext: String? = nil) async throws -> String {
        logger.info("Generating tests for entire file")
        let fileHeader = """
        Generate a complete Swift unit test file for the following source code:
        
        \(code)
        """
        var addCtx: String? = additionalContext
        
        if let additionalContext {
            addCtx = """
        This is additional context:
        
        \(additionalContext)
        """
        }
        
        var cusPrompt: String? = customPrompt
        
        if let customPrompt {
            cusPrompt = """
        This is custom prompt from user:
        
        \(customPrompt)
        """
        }
        let prompt = [fileHeader, addCtx, cusPrompt].compactMap{ $0 }.joined(separator: "\n\n")
        return try await OllamaBridge.shared.send(prompt: prompt)
    }
    
    public static func explainCode(_ code: String) async throws -> String {
        let prompt = "Explain what the following Swift code does:\n\n\(code)"
        return try await OllamaBridge.shared.send(prompt: prompt)
    }
    
    public static func refactorCode(_ code: String) async throws -> String {
        let prompt = "Refactor and improve the following Swift code:\n\n\(code)"
        return try await OllamaBridge.shared.send(prompt: prompt)
    }
    
    public static func summarizeCode(_ code: String) async throws -> String {
        let prompt = "Briefly summarize what this Swift code does:\n\n\(code)"
        return try await OllamaBridge.shared.send(prompt: prompt)
    }
    
    public static func generateDocumentation(for code: String, style: DocumentationStyle, declarations: [String], returnFormat: DocumentationReturnFormat) async throws -> String {
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
        
        let formattedDeclarations = declarations.map({"- \($0)"}).joined(separator: "\n")
        
        let prompt = """
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
        return try await OllamaBridge.shared.send(prompt: prompt)
    }
    
    public static func reviewCode(_ code: String) async throws -> String {
        let prompt = """
        Perform an AI code review of the following Swift code. Identify issues, improvements, and adherence to best practices:
        
        \(code)
        """
        return try await OllamaBridge.shared.send(prompt: prompt)
    }
    
    public static func generateReadme(for code: String) async throws -> String {
        let prompt = """
        Generate a README.md based on this Swift code with a description of its purpose, a brief usage example, and key functions:
        
        \(code)
        """
        return try await OllamaBridge.shared.send(prompt: prompt)
    }
}

