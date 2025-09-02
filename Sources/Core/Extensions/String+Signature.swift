//
//  String+Signature.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 02.09.2025.
//

import Foundation

extension String {
    /// Normalizes user input to the same canonical format used for signature keys.
    ///
    /// Collapses whitespace, trims, and removes spaces around `:` and `->`
    /// so that different textual variants map to the same comparison key.
    func canonicalizedSignatureKey() -> String {
        return self
        // collapse newlines & runs of spaces
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        // no spaces BEFORE "(" and AFTER "("
            .replacingOccurrences(of: "\\s*\\(", with: "(", options: .regularExpression)
            .replacingOccurrences(of: "\\(\\s+", with: "(", options: .regularExpression)
        
        // no spaces around ":" and "->"
            .replacingOccurrences(of: "\\s*:\\s*", with: ":", options: .regularExpression)
            .replacingOccurrences(of: "\\s*->\\s*", with: "->", options: .regularExpression)
        
        // commas: strip spaces BEFORE, ensure single space AFTER
            .replacingOccurrences(of: "\\s+,", with: ",", options: .regularExpression)
            .replacingOccurrences(of: ",\\s*", with: ", ", options: .regularExpression)
        
        // trim edges
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Rough heuristic: returns `true` if the string looks like a function
    /// signature/header rather than just a bare name.
    var isProbablySignatureLike: Bool {
        // Starts with `func` — definitely a signature
        if self.hasPrefix("func") { return true }

        // Has parameter parentheses or generics `<...>`
        if self.contains("(") && self.contains(")") { return true }
        if self.contains("<") && self.contains(">") { return true }

        // Presence of async/throws/-> is also a signal
        if self.contains("->") || self.contains("throws") || self.contains("rethrows") || self.contains("async") {
            return true
        }

        // Contains a `where` clause
        if self.contains(" where ") { return true }

        return false
    }
}
