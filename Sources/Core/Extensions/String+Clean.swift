//
//  String+Clean.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 29.08.2025.
//

import Foundation

public extension String {
    /// Removes Markdown code fences from AI-generated snippets and trims whitespace.
    ///
    /// Useful when models return code wrapped in ```swift fences.
    /// - Returns: Cleaned Swift source code.
    func cleanGeneratedCode() -> String {
        self
            .replacingOccurrences(of: "```swift", with: "")
            .replacingOccurrences(of: "```", with: "")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
