//
//  DeclarationCollector.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 18.06.2025.
//

import Foundation
import SwiftSyntax
import SwiftParser
import os.log

/// Visits a Swift syntax tree and collects top-level declarations
/// (`func`, `init`, `class`, `struct`, `enum`, `protocol`, `extension`).
public final class DeclarationCollector: SyntaxVisitor {
    /// Collected declaration nodes in the order they appear.
    public private(set) var declarations: [DeclSyntax] = []

    /// Subsystem logger for diagnostics.
    private let logger = Logger(subsystem: "SwiftMind", category: "DeclarationCollector")
    
    /// Collects function declarations.
    override public func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        return handle(node: node)
    }

    /// Collects initializers.
    override public func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        return handle(node: node)
    }

    /// Collects class declarations.
    override public func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        return handle(node: node)
    }

    /// Collects struct declarations.
    override public func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        return handle(node: node)
    }

    /// Collects enum declarations.
    override public func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        return handle(node: node)
    }

    /// Collects protocol declarations.
    override public func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        return handle(node: node)
    }

    /// Collects extensions.
    override public func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        return handle(node: node)
    }
    
    /// Parses the given Swift source and returns a populated collector.
    /// - Parameter code: Raw Swift source text.
    /// - Returns: An instance whose `declarations` contains discovered nodes.
    public static func collectDeclarations(from code: String) throws -> DeclarationCollector {
        let sourceFile = Parser.parse(source: code)
        let collector = DeclarationCollector(viewMode: .sourceAccurate)
        collector.walk(sourceFile)
        return collector
    }
    
    /// Common handler that appends a declaration and continues traversal.
    private func handle(node: any DeclSyntaxProtocol) -> SyntaxVisitorContinueKind {
        declarations.append(DeclSyntax(node))
        return .visitChildren
    }
}
