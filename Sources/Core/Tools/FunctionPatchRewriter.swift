//
//  FunctionPatchRewriter.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 15.09.2025.
//

import Foundation
import SwiftSyntax
import SwiftParser

public enum FunctionPatchError: Error {
    case parseFailed
    case noFunctionInPatch
}

public final class FunctionPatchRewriter: SyntaxRewriter {
    private let replacements: [String: String] // canonicalSignature -> new function source
    private var processed = 0
    private var skipped = 0

    public static func apply(to code: String,
                             replacementsBySignature: [String: String],
                             writeTo fileURL: URL) throws -> (processed: Int, skipped: Int) {
        let file = Parser.parse(source: code)
        let r = FunctionPatchRewriter(replacements: replacementsBySignature)
        let newTree = r.visit(file)
        try "\(newTree)".write(to: fileURL, atomically: true, encoding: .utf8)
        return (r.processed, r.skipped)
    }

    private init(replacements: [String: String]) {
        // ключи ожидаем в формате signatureString/canonicalSignatureKey()
        self.replacements = replacements
    }

    override public func visit(_ node: FunctionDeclSyntax) -> DeclSyntax {
        let sig = node.signatureString
        guard let newSource = replacements[sig] ?? replacements[node.canonicalSignatureKey()] else {
            return DeclSyntax(super.visit(node))
        }

        // Парсим новую функцию из исходника, берём первую FunctionDeclSyntax
        let parsed = Parser.parse(source: newSource)
        guard let newFn = parsed.statements.compactMap({ stmt in
            stmt.item.as(FunctionDeclSyntax.self)
        }).first else {
            skipped += 1
            return DeclSyntax(super.visit(node))
        }

        // Сохраняем лидирующие комментарии/отступы исходной функции
        let withTrivia = newFn.with(\.leadingTrivia, node.leadingTrivia)
                              .with(\.trailingTrivia, node.trailingTrivia)

        processed += 1
        return DeclSyntax(withTrivia) // подменили ноду
    }
}
