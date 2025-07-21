//
//  DocInserter.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 18.06.2025.
//

import Foundation
import SwiftSyntax

public final class DocInserter: SyntaxRewriter {
    private let docs: [String]
    private let skipExisting: Bool
    private var declarationIndex = 0
    private var processedCount = 0
    private var skippedCount = 0
    
    public var totalProcessed: Int { processedCount }
    public var totalSkipped: Int { skippedCount }
    
    init(docs: [String], skipExisting: Bool) {
        self.docs = docs
        self.skipExisting = skipExisting
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
    
    // MARK: - Helper Methods
    private func processDeclaration(
        _ node: DeclSyntax,
        continueVisiting: (DeclSyntax) -> DeclSyntax
    ) -> DeclSyntax {
        // Проверяем, нужно ли пропустить уже задокументированные
        if skipExisting && hasExistingDocumentation(node) {
            skippedCount += 1
            return continueVisiting(node)
        }
        
        // Проверяем, есть ли еще документация
        guard declarationIndex < docs.count else {
            print("⚠️ Warning: More declarations than documentation blocks (at index \(declarationIndex))")
            return continueVisiting(node)
        }
        
        // Добавляем документацию
        let docText = docs[declarationIndex]
        declarationIndex += 1
        processedCount += 1
        
        let documentedNode = addDocumentation(to: node, docText: docText)
        return continueVisiting(documentedNode)
    }
    
    private func addDocumentation(to node: DeclSyntax, docText: String) -> DeclSyntax {
        let triviaElements: [TriviaPiece] = docText
            .split(separator: "\n")
            .flatMap { line in
                [
                    .docLineComment("/// \(line)"),
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
}
