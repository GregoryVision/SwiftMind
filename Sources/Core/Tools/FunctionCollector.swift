//
//  FunctionCollector.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 22.08.2025.
//

import SwiftSyntax
import SwiftParser
import os.log

public final class FunctionCollector: SyntaxVisitor {
    /// Discovered functions in the visited syntax tree.
    public private(set) var functions: [FunctionDeclSyntax] = []

    /// When `true`, collects only top-level functions (outside types/extensions).
    private let topLevelOnly: Bool

    /// Subsystem logger for diagnostics (reserved for future use).
    private let logger = Logger(subsystem: "SwiftMind", category: "FunctionCollector")

    /// Creates a function collector.
    /// - Parameter topLevelOnly: If `true`, collect only top-level functions (outside types/extensions).
    public init(topLevelOnly: Bool = false,
                viewMode: SyntaxTreeViewMode = .sourceAccurate) {
        self.topLevelOnly = topLevelOnly
        super.init(viewMode: viewMode)
    }

    /// Visits function declarations and appends them to `functions` according to `topLevelOnly`.
    public override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        if !topLevelOnly || isTopLevel(node) {
            functions.append(node)
        }
        return .visitChildren
    }

    /// Collects functions from a raw Swift source string.
    /// - Parameters:
    ///   - source: Swift source text.
    ///   - topLevelOnly: If `true`, collect only top-level functions.
    /// - Returns: A configured `FunctionCollector` with populated `functions`.
    public static func collect(from source: String,
                               topLevelOnly: Bool = false) -> FunctionCollector {
        let file = Parser.parse(source: source)
        let v = FunctionCollector(topLevelOnly: topLevelOnly, viewMode: .sourceAccurate)
        v.walk(file)
        return v
    }

    // MARK: - Helpers

    /// Checks whether a node represents a top-level function (not inside a type/extension).
    private func isTopLevel(_ node: SyntaxProtocol) -> Bool {
        // For top-level functions the parent chain is:
        // FunctionDeclSyntax -> CodeBlockItemSyntax -> SourceFileSyntax
        var p = node.parent
        while let parent = p {
            if parent.is(SourceFileSyntax.self) { return true }
            // If we meet any declaration node (and it's not the source file), it's nested.
            if parent.is(DeclSyntax.self) && !parent.is(SourceFileSyntax.self) {
                return false
            }
            p = parent.parent
        }
        return false
    }
}

// MARK: - Convenience representations

public extension FunctionDeclSyntax {
    /// Declaration without the body (attributes/modifiers preserved).
    var declarationString: String {
        self.with(\.body, nil).trimmedDescription
    }

    /// Full textual representation of the function (including the body).
    var fullText: String {
        self.trimmedDescription
    }
}

extension FunctionCollector {
    /// Returns precise function signatures (headers) for a given name (all overloads).
    public func functionSignatures(named name: String) -> [String] {
        functions.compactMap { fnDecl in
            guard fnDecl.name.text == name else { return nil }

            // Take full header (attributes + modifiers + func keyword + identifier + signature)
            let header = fnDecl.trimmedDescription

            // Strip body if present
            if let body = fnDecl.body {
                let bodyText = body.trimmedDescription
                if let range = header.range(of: bodyText) {
                    return String(header[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            return header
        }
    }

    /// Returns the first signature for a given function name (if any).
    public func firstFunctionSignature(named name: String) -> String? {
        return functionSignatures(named: name).first
    }
}

extension FunctionCollector {
    /// Universal lookup that accepts either a simple name or a full signature/header.
    /// - If it's a name — returns all overloads by that name.
    /// - If it's a signature — returns exact matches by canonical signature.
    /// - If it's a shortened header (no `func` or truncated) — tries prefix-match on the canonical signature.
    public func functionDecls(target: String) -> [FunctionDeclSyntax] {
        let t = target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return [] }

        // 1) Looks like a signature? (has parameter parens/generics/throws/-> or starts with `func`)
        if t.isProbablySignatureLike {
            // Exact match by canonicalized signature
            let key = t.canonicalizedSignatureKey()
            let exact = functions.filter { $0.canonicalSignatureKey() == key }
            if !exact.isEmpty { return exact }

            // Fallback: prefix-match (user may provide a shortened header)
            return functions.filter { $0.canonicalSignatureKey().hasPrefix(key) }
        }

        // 2) Otherwise treat it as a plain name
        return functions.filter { $0.name.text == t }
    }

    /// All functions with the given name (all overloads).
    public func functionDecls(named name: String) -> [FunctionDeclSyntax] {
        functions.filter { $0.name.text == name }
    }

    /// Lookup by canonical signature (when the user provided a full signature).
    public func functionDecls(matching target: String) -> [FunctionDeclSyntax] {
        let normalizedTarget = target.canonicalizedSignatureKey()
        return functions.filter { $0.canonicalSignatureKey() == normalizedTarget }
    }
}

private extension String {
    /// Normalizes user input to the same canonical format used for signature keys.
    ///
    /// Collapses whitespace, trims, and removes spaces around `:` and `->`
    /// so that different textual variants map to the same comparison key.
    func canonicalizedSignatureKey() -> String {
        self
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: " ", with: " ") // one space
            .replacingOccurrences(of: " : ", with: ":")
            .replacingOccurrences(of: " -> ", with: "->")
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
