//
//  ReviewCodeUseCase.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 15.08.2025.
//

import Foundation
import os.log

public protocol ReviewCodeUseCase {
    func review(code: String) async throws -> String

    func comments(code: String,
                  declarations: [String],
                  expectedCount: Int,
                  returnFormat: ReviewReturnFormat) async throws -> [String]
}

public enum ReviewReturnFormat: String {
    case blocks      // separator: \n\n
    case jsonArray   // JSON: ["...", "..."]
}

public struct ReviewCodeUseCaseImpl: ReviewCodeUseCase {
    private let ollama: OllamaBridgeProtocol
    private let config: SwiftMindConfigProtocol
    private let logger = Logger(subsystem: "SwiftMind", category: "ReviewCode")

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

    public func review(code: String) async throws -> String {
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
        return try await ollama.send(prompt: prompt, model: config.defaultModel)
    }

    public func comments(code: String,
                         declarations: [String],
                         expectedCount: Int,
                         returnFormat: ReviewReturnFormat = .blocks) async throws -> [String] {
        let formattedTypes = declarations.map { "- \($0)" }.joined(separator: "\n")

        let prompt = """
        \(roleModelPromptInstruction)

        Perform a professional Swift code review.

        Review ONLY declarations of the following kinds (in the exact order they appear in the source code):
        \(formattedTypes)

        OUTPUT FORMAT (strict):
        - Return review comments as plain text blocks (no markdown fences).
        - Return EXACTLY \(expectedCount) blocks.
        - For declarations that do not require a comment, return this exact string: __NO_COMMENT__
        - Separate EACH block with exactly TWO newlines (\\n\\n).
        - Each block should correspond to the next matching declaration in order.
        - Do NOT include original code or any extra prose outside the blocks.

        Focus on: correctness, safety, performance, API design, naming, Swift best practices.

        Swift code:
        \(code)
        """

        let text = try await ollama.send(prompt: prompt, model: config.defaultModel)

        return text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
}
