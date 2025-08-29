//
//  FunctionInserter.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 25.08.2025.
//

import Foundation
import SwiftSyntax
import SwiftParser

/// Rewrites a Swift source file by inserting either documentation comments (`///`)
/// or inline review comments (`// REVIEW:`) before target function declarations.
///
/// Matching is done by exact function signature (`signatureString`) against the provided map.
public final class FunctionDocInserter: SyntaxRewriter {
    /// Map of `functionSignature -> prepared comment text` to insert.
    private let commentsBySignature: [String: String]
    /// When `true`, functions that already contain the respective comment kind are not touched.
    private let skipExisting: Bool
    /// Target comment kind to insert (`.documentation` or `.review`).
    private let kind: CommentInsertionKind

    /// Number of functions successfully processed in this run.
    private(set) var processed = 0
    /// Number of functions skipped due to existing comments (when `skipExisting == true`).
    private(set) var skipped = 0

    /// Creates a new inserter.
    /// - Parameters:
    ///   - commentsBySignature: Dictionary keyed by function signature (`signatureString`).
    ///   - skipExisting: If `true`, leave functions that already have such comments unchanged.
    ///   - kind: Type of comment to insert.
    public init(
        commentsBySignature: [String: String],
        skipExisting: Bool,
        kind: CommentInsertionKind
    ) {
        self.commentsBySignature = commentsBySignature
        self.skipExisting = skipExisting
        self.kind = kind
    }

    /// Visits each function declaration and injects the requested comment trivia when matched.
    override public func visit(_ node: FunctionDeclSyntax) -> DeclSyntax {
        let sig = node.signatureString

        // No comment prepared for this signature — delegate to super.
        guard let comment = commentsBySignature[sig] else {
            return DeclSyntax(super.visit(node))
        }

        // Respect existing content if requested.
        if skipExisting, hasExisting(for: node) {
            skipped += 1
            return DeclSyntax(super.visit(node))
        }

        // Build new leading trivia with our comment block.
        let newLeading = buildLeadingTrivia(
            existing: node.leadingTrivia,
            comment: comment,
            kind: kind
        )

        var newNode = node
        newNode = newNode.with(\.leadingTrivia, newLeading)

        processed += 1
        return DeclSyntax(super.visit(newNode))
    }
    
    /// Returns `true` if the node already contains a comment of the requested kind.
    private func hasExisting(for node: FunctionDeclSyntax) -> Bool {
        let hasDoc = node.leadingTrivia.contains {
            if case .docLineComment = $0 { return true }
            if case .docBlockComment = $0 { return true }
            return false
        }
        let hasReview = node.leadingTrivia.contains {
            if case let .lineComment(text) = $0, text.contains("REVIEW:") { return true }
            return false
        }
        switch kind {
        case .documentation: return hasDoc
        case .review:        return hasReview
        }
    }

    /// Applies insertion to a string of Swift code and writes the result to `fileURL`.
    ///
    /// - Parameters:
    ///   - code: Original Swift source.
    ///   - commentsBySignature: Map of signatures to comment bodies to inject.
    ///   - skipExisting: When `true`, do not overwrite existing comments of that kind.
    ///   - kind: Comment kind to insert (documentation vs review).
    ///   - fileURL: Destination path to write modified source.
    /// - Returns: Tuple with `(processed, skipped)` counts.
    @discardableResult
    public static func apply(
        to code: String,
        commentsBySignature: [String:String],
        skipExisting: Bool,
        kind: CommentInsertionKind,
        writeTo fileURL: URL
    ) throws -> (processed: Int, skipped: Int) {
        // Nothing to insert — avoid rewriting file.
        guard !commentsBySignature.isEmpty else { return (0, 0) }

        let file = Parser.parse(source: code)
        let rewriter = FunctionDocInserter(
            commentsBySignature: commentsBySignature,
            skipExisting: skipExisting,
            kind: kind
        )
        let newTree = rewriter.visit(file)
        try "\(newTree)".write(to: fileURL, atomically: true, encoding: .utf8)
        return (rewriter.processed, rewriter.skipped)
    }
    
    /// Builds new leading trivia by prepending a cleaned, properly-prefixed comment block
    /// to the existing trivia.
    /// - Parameters:
    ///   - existing: Current leading trivia on the function node.
    ///   - comment: Raw comment text (may include Markdown code fences or existing `///`/`//` prefixes).
    ///   - kind: Whether to emit `///` doc lines or `// REVIEW:` block lines.
    /// - Returns: Combined trivia with inserted comment and preserved existing trivia.
    private func buildLeadingTrivia(
        existing: Trivia,
        comment: String,
        kind: CommentInsertionKind
    ) -> Trivia {
        // Normalize and strip code fences/newline variants.
        let cleaned = comment.cleanGeneratedCode()

        // Remove common prefixes from each line and trim.
        func stripPrefixes(_ raw: Substring) -> String {
            var s = String(raw).trimmingCharacters(in: .whitespaces)

            // Drop block-comment artifacts.
            if s == "*/" || s.hasPrefix("* ") || s == "*" { return "" }
            if s.hasPrefix("/*") { return "" }

            // Drop single-line comment markers.
            if s.hasPrefix("///") {
                s.removeFirst(3)
                s = s.trimmingCharacters(in: .whitespaces)
            } else if s.hasPrefix("//") {
                s.removeFirst(2)
                s = s.trimmingCharacters(in: .whitespaces)
            }
            
            // Drop leading "REVIEW:" (any case).
            let lower = s.lowercased()
            if lower.hasPrefix("review:") {
                s = String(s.dropFirst("REVIEW:".count)).trimmingCharacters(in: .whitespaces)
            }
            return s
        }

        var lines = cleaned
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(stripPrefixes)
            .map { $0.trimmingCharacters(in: .whitespaces) }

        // Trim blank first/last lines after cleanup.
        while lines.first?.isEmpty == true { lines.removeFirst() }
        while lines.last?.isEmpty == true { lines.removeLast() }

        guard !lines.isEmpty else { return existing }

        var pieces: [TriviaPiece] = [.newlines(2)]

        switch kind {
        case .documentation:
            for (i, line) in lines.enumerated() {
                pieces.append(.docLineComment("/// \(line)"))
                if i < lines.count - 1 { pieces.append(.newlines(1)) }
            }

        case .review:
            // Keep the current two-line header style:
            // `// REVIEW:` on its own line, then the text lines.
            pieces.append(.lineComment("// REVIEW: \n// \(lines[0])"))
            if lines.count > 1 { pieces.append(.newlines(1)) }
            for i in 1..<lines.count {
                let line = lines[i]
                pieces.append(.lineComment("// \(line)"))
                if i < lines.count - 1 { pieces.append(.newlines(1)) }
            }
        }

        return Trivia(pieces: pieces + existing.pieces)
    }
}
