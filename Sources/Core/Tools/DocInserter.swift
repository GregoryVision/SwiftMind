//
//  DocInserter.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 18.06.2025.
//

import Foundation
import SwiftSyntax
import SwiftParser

public enum CommentInsertionKind {
    case documentation  // "///"
    case review         // "// REVIEW:"
}

public final class DocInserter: SyntaxRewriter {
    private let docs: [String]
    private let skipExisting: Bool
    private var declarationIndex = 0
    private var processedCount = 0
    private var skippedCount = 0
    private let commentKind: CommentInsertionKind
    private let commentPrefix: String
    
    public var totalProcessed: Int { processedCount }
    public var totalSkipped: Int { skippedCount }
    
    init(docs: [String], skipExisting: Bool, kind: CommentInsertionKind) {
        self.docs = docs
        self.skipExisting = skipExisting
        self.commentKind = kind
        self.commentPrefix = kind == .review ? "// REVIEW:" : "///"
    }
    
    // MARK: - Function Declarations
    override public func visit(_ node: FunctionDeclSyntax) -> DeclSyntax {
        return processDeclaration(node.as(DeclSyntax.self)!) { processedNode in
            super.visit(processedNode.as(FunctionDeclSyntax.self)!)
        }
    }
    
    // MARK: - Initializer Declarations
    override public func visit(_ node: InitializerDeclSyntax) -> DeclSyntax {
        return processDeclaration(node.as(DeclSyntax.self)!) { processedNode in
            super.visit(processedNode.as(InitializerDeclSyntax.self)!)
        }
    }
    
    // MARK: - Class Declarations
    override public func visit(_ node: ClassDeclSyntax) -> DeclSyntax {
        return processDeclaration(node.as(DeclSyntax.self)!) { processedNode in
            super.visit(processedNode.as(ClassDeclSyntax.self)!)
        }
    }
    
    // MARK: - Struct Declarations
    override public func visit(_ node: StructDeclSyntax) -> DeclSyntax {
        return processDeclaration(node.as(DeclSyntax.self)!) { processedNode in
            super.visit(processedNode.as(StructDeclSyntax.self)!)
        }
    }
    
    // MARK: - Enum Declarations
    override public func visit(_ node: EnumDeclSyntax) -> DeclSyntax {
        return processDeclaration(node.as(DeclSyntax.self)!) { processedNode in
            super.visit(processedNode.as(EnumDeclSyntax.self)!)
        }
    }
    
    // MARK: - Protocol Declarations
    override public func visit(_ node: ProtocolDeclSyntax) -> DeclSyntax {
        return processDeclaration(node.as(DeclSyntax.self)!) { processedNode in
            super.visit(processedNode.as(ProtocolDeclSyntax.self)!)
        }
    }
    
    // MARK: - Extension Declarations
    override public func visit(_ node: ExtensionDeclSyntax) -> DeclSyntax {
        return processDeclaration(node.as(DeclSyntax.self)!) { processedNode in
            super.visit(processedNode.as(ExtensionDeclSyntax.self)!)
        }
    }
    
    public static func applyDocInserter(to code: String, docs: [String], skipExisting: Bool, fileURL: URL,  kind: CommentInsertionKind) throws -> (Int, Int) {
        let sourceFile = Parser.parse(source: code)
        let rewriter = DocInserter(docs: docs, skipExisting: skipExisting, kind: kind)
        let newTree = rewriter.visit(sourceFile)
        try "\(newTree)".write(to: fileURL, atomically: true, encoding: .utf8)
        return (rewriter.totalProcessed, rewriter.totalSkipped)
    }
    
    // MARK: - Helper Methods
    private func processDeclaration(
        _ node: DeclSyntax,
        continueVisiting: (DeclSyntax) -> DeclSyntax
    ) -> DeclSyntax {
    
        if skipExisting {
            switch commentKind {
            case .documentation:
                if hasExistingDocumentation(node) {
                    skippedCount += 1
                    return continueVisiting(node)
                }
            case .review:
                if hasExistingReviewComment(node) {
                    skippedCount += 1
                    return continueVisiting(node)
                }
            }
        }
        
        guard declarationIndex < docs.count else {
            print("⚠️ Warning: More declarations than documentation blocks (at index \(declarationIndex))")
            return continueVisiting(node)
        }
        
        // Добавляем комментарии (документацию или REVIEW)
        let docText = docs[declarationIndex]
        declarationIndex += 1
        
        if docText == "__NO_COMMENT__" {
            skippedCount += 1
            return continueVisiting(node)
        }
        
        processedCount += 1
        
        let documentedNode = addComments(to: node, commentText: docText, commentPrefix: commentPrefix)
        return continueVisiting(documentedNode)
    }
    
    /// Добавляет комментарии (например, документацию или REVIEW) перед декларацией.
    private func addComments(to node: DeclSyntax, commentText: String, commentPrefix: String = "///") -> DeclSyntax {
        let triviaElements: [TriviaPiece] = commentText
            .split(separator: "\n")
            .flatMap { line in
                [
                    .docLineComment("\(commentPrefix) \(line)"),
                    .newlines(1)
                ]
            }
        let leadingTrivia = Trivia(pieces: triviaElements)
        return DeclSyntax(node.with(\.leadingTrivia, leadingTrivia + node.leadingTrivia))
    }
    
    private func hasExistingDocumentation(_ node: DeclSyntax) -> Bool {
        return node.leadingTrivia.contains { trivia in
            switch trivia {
            case .docLineComment, .docBlockComment:
                return true
            default:
                return false
            }
        }
    }
    private func hasExistingReviewComment(_ node: DeclSyntax) -> Bool {
        return node.leadingTrivia.contains { trivia in
            switch trivia {
            case .lineComment(let text):
                return text.contains("REVIEW:")
            default:
                return false
            }
        }
    }
}
