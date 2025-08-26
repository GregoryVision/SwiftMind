//
//  FunctionInserter.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 25.08.2025.
//

import Foundation
import SwiftSyntax
import SwiftParser

public final class FunctionDocInserter: SyntaxRewriter {
    private let commentsBySignature: [String: String]
    private let skipExisting: Bool
    private let kind: CommentInsertionKind
    private let commentPrefix: String
    private(set) var processed = 0
    private(set) var skipped = 0

    public init(commentsBySignature: [String: String],
                skipExisting: Bool,
                kind: CommentInsertionKind) {
        self.commentsBySignature = commentsBySignature
        self.skipExisting = skipExisting
        self.kind = kind
        self.commentPrefix = (kind == .review) ? "// REVIEW:" : "///"
    }

    override public func visit(_ node: FunctionDeclSyntax) -> DeclSyntax {
        
        let sig = node.signatureString
        
        guard let comment = commentsBySignature[sig] else {
            return DeclSyntax(super.visit(node))
        }
        
        if skipExisting, hasExisting(for: node) {
            skipped += 1
            return DeclSyntax(super.visit(node))
        }

        var newNode = node
        let newLeading = buildLeadingTrivia(
            existing: node.leadingTrivia,
            comment: comment,
            kind: kind
        )
        newNode = newNode.with(\.leadingTrivia, newLeading)
        
        processed += 1
        return DeclSyntax(super.visit(newNode))
    }
    
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

    public static func apply(to code: String,
                             commentsBySignature: [String:String],
                             skipExisting: Bool,
                             kind: CommentInsertionKind,
                             writeTo fileURL: URL) throws -> (processed: Int, skipped: Int) {
        let file = Parser.parse(source: code)
        let r = FunctionDocInserter(commentsBySignature: commentsBySignature,
                                 skipExisting: skipExisting,
                                 kind: kind)
        let newTree = r.visit(file)
        try "\(newTree)".write(to: fileURL, atomically: true, encoding: .utf8)
        return (r.processed, r.skipped)
    }
    
    private func buildLeadingTrivia(
        existing: Trivia,
        comment: String,
        kind: CommentInsertionKind
    ) -> Trivia {
        let cleaned = comment
            .replacingOccurrences(of: "```swift", with: "")
            .replacingOccurrences(of: "```", with: "")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        func stripPrefixes(_ raw: Substring) -> String {
            var s = String(raw).trimmingCharacters(in: .whitespaces)

            if s == "*/" || s.hasPrefix("* ") || s == "*" { return "" }
            if s.hasPrefix("/*") { return "" }

            if s.hasPrefix("///") {
                s.removeFirst(3)
                s = s.trimmingCharacters(in: .whitespaces)
            } else if s.hasPrefix("//") {
                s.removeFirst(2)
                s = s.trimmingCharacters(in: .whitespaces)
            }
            
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
