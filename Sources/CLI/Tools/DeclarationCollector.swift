//
//  DeclarationCollector.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 18.06.2025.
//

import Foundation
import SwiftSyntax
import os.log

public final class DeclarationCollector: SyntaxVisitor {
    private(set) var declarations: [DeclSyntax] = []
    private let logger = Logger(subsystem: "SwiftMind", category: "Test")
    
    override public func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        return handle(node: node)
    }

    override public func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        return handle(node: node)
    }

    override public func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        return handle(node: node)
    }

    override public func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        return handle(node: node)
    }

    override public func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        return handle(node: node)
    }

    override public func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        return handle(node: node)
    }

    override public func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        return handle(node: node)
    }
    
    private func handle(node: any DeclSyntaxProtocol) -> SyntaxVisitorContinueKind {
        guard let declSyntax = node.as(DeclSyntax.self) else {
            logger.warning("Failed to convert \(node.syntaxNodeType) to DeclSyntax")
            return .visitChildren
        }
        declarations.append(declSyntax)
        return .visitChildren
    }
}
