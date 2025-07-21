//
//  PromptSanitizer.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 14.07.2025.
//

import Foundation

public enum PromptSanitizer {
    public static func sanitize(_ input: String, maxLength: Int) throws -> String {
        guard input.count <= maxLength else {
            throw SwiftMindError.promptTooLong(input.count, maxLength)
        }
        return String(input.prefix(maxLength))
    }
}
