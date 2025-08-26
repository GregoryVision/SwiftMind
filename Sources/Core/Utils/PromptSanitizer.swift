//
//  PromptSanitizer.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 14.07.2025.
//

import Foundation

public enum PromptSanitizer {
    public static func sanitize(_ input: String, maxLength: Int) throws -> (String, SwiftMindError?) {
        let sanitizedPrompt = String(input.prefix(maxLength))
        guard input.count <= maxLength else {
            return (sanitizedPrompt, SwiftMindError.promptTooLong(input.count, maxLength))
        }
        return (sanitizedPrompt, nil)
    }
}
