//
//  AIUseCases.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 06.06.2025.
//

import Foundation
import os.log

public protocol AIUseCasesProtocol {
    func generateTests(for code: String,
                       functionName: String,
                       customPrompt: String?,
                       additionalContext: String?, cfg: SwiftMindConfigProtocol) async throws -> String
    func generateTestsForEntireFile(_ code: String,
                                    customPrompt: String?,
                                    additionalContext: String?,
                                    cfg: SwiftMindConfigProtocol) async throws -> String
    func explainCode(_ code: String,
                     cfg: SwiftMindConfigProtocol) async throws -> String
    func refactorCode(_ code: String,
                      cfg: SwiftMindConfigProtocol) async throws -> String
    func summarizeCode(_ code: String,
                       cfg: SwiftMindConfigProtocol) async throws -> String
    func generateDocumentation(for code: String,
                               style: DocumentationStyle,
                               declarations: [String],
                               returnFormat: DocumentationReturnFormat,
                               cfg: SwiftMindConfigProtocol) async throws -> String
    func reviewCode(_ code: String, cfg: SwiftMindConfigProtocol) async throws -> String
    func reviewComments(for code: String,
                            declarations: [String],
                            expectedCount: Int,
                            cfg: SwiftMindConfigProtocol,
                            returnFormat: ReviewReturnFormat) async throws -> [String]
}

public enum ReviewReturnFormat: String {
    case blocks      // separator: \n\n
    case jsonArray   // JSON: ["...", "..."]
}

// ToDo: Разделить на разные юзкейсы?

public final class AIUseCases: AIUseCasesProtocol {
    
    private let logger = Logger(subsystem: "SwiftMind", category: "AIUseCases")
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
    
    public func generateTests(for code: String,
                              functionName: String,
                              customPrompt: String? = nil,
                              additionalContext: String? = nil,
                              cfg: SwiftMindConfigProtocol) async throws -> String {
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
        
        let prompt = [fileHeader, roleModelPromptInstruction, testInstruction, addCtx, cusPrompt].compactMap { $0 }.joined(separator: "\n\n")
        return try await ollama.send(prompt: prompt, model: cfg.defaultModel)
    }
    
    public func generateTestsForEntireFile(_ code: String,
                                           customPrompt: String? = nil,
                                           additionalContext: String? = nil,
                                           cfg: SwiftMindConfigProtocol) async throws -> String {
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
        
        Use XCTest, avoid redundant tests, and ensure good naming conventions.
        """
        }
        let prompt = [fileHeader, roleModelPromptInstruction, addCtx, cusPrompt].compactMap { $0 }.joined(separator: "\n\n")
        return try await ollama.send(prompt: prompt, model: cfg.defaultModel)
    }
    
    public func explainCode(_ code: String,
                            cfg: SwiftMindConfigProtocol) async throws -> String {
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
        return try await ollama.send(prompt: prompt, model: cfg.defaultModel)
    }
    
    public func refactorCode(_ code: String,
                             cfg: SwiftMindConfigProtocol) async throws -> String {
        let prompt = "Refactor and improve the following Swift code:\n\n\(code)"
        return try await ollama.send(prompt: prompt, model: cfg.defaultModel)
    }
    // MARK: Todo: Может быть объеденить с explain и передавать в параметр степень детализации?
    public func summarizeCode(_ code: String,
                              cfg: SwiftMindConfigProtocol) async throws -> String {
        let prompt = "Briefly summarize what this Swift code does:\n\n\(code)"
        return try await ollama.send(prompt: prompt, model: cfg.defaultModel)
    }
    
    public func generateDocumentation(for code: String,
                                      style: DocumentationStyle,
                                      declarations: [String],
                                      returnFormat: DocumentationReturnFormat,
                                      cfg: SwiftMindConfigProtocol) async throws -> String {
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
        return try await ollama.send(prompt: prompt, model: cfg.defaultModel)
    }
    
    public func reviewCode(_ code: String,
                           cfg: SwiftMindConfigProtocol) async throws -> String {
        let prompt = """
        \(roleModelPromptInstruction)
        
        Perform a professional code review for the following Swift code.
        Insert your review comments directly into the code using the following format:
        - Use `// REVIEW:` comments above or beside the lines where issues, improvements, or best practices should be noted.
        - Keep original code intact.
        - Do not output additional explanation outside the code, only return the modified Swift code with inline comments.
        
        Swift code to review:
        
        \(code)
        """
        return try await ollama.send(prompt: prompt, model: cfg.defaultModel)
    }
    
    public func reviewComments(for code: String,
                            declarations: [String],              // например: ["func","class","struct"]
                            expectedCount: Int,                  // сколько блоков ждём
                            cfg: SwiftMindConfigProtocol,
                            returnFormat: ReviewReturnFormat = .blocks) async throws -> [String] {

            // Сформируем список типов для промпта
            let formattedTypes = declarations.map { "- \($0)" }.joined(separator: "\n")

            // Просим РОВНО expectedCount блоков, по ПОРЯДКУ деклараций
            let prompt = """
            \(roleModelPromptInstruction)

            Perform a professional Swift code review.

            Review ONLY declarations of the following kinds (in the exact order they appear in the source code):
            \(formattedTypes)

            OUTPUT FORMAT (strict):
            - Return review comments as plain text blocks (no markdown fences).
            - Return EXACTLY \(expectedCount) blocks.
            - Separate EACH block with exactly TWO newlines (\\n\\n).
            - Each block should correspond to the next matching declaration in order.
            - Do NOT include original code or any extra prose outside the blocks.

            Focus on: correctness, safety, performance, API design, naming, Swift best practices.

            Swift code:
            \(code)
            """

            let text = try await ollama.send(prompt: prompt, model: cfg.defaultModel)

            let blocks = text
                .replacingOccurrences(of: "\r\n", with: "\n")
                .components(separatedBy: "\n\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            return blocks
        }
}
