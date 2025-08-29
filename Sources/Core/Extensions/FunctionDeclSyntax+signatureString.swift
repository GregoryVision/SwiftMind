//
//  FunctionDeclSyntax+signatureString.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 25.08.2025.
//

import Foundation
import SwiftSyntax

public extension FunctionDeclSyntax {
    /// Canonicalized function signature string.
    ///
    /// Stable against formatting, preserves parameter labels and types,
    /// includes generics, `async`/`throws` markers, and return type.
    /// Default values and attributes are stripped.
    ///
    /// Example:
    /// ```swift
    /// func foo(bar x: Int, y: String) async throws -> Bool
    /// ```
    /// becomes
    /// ```
    /// func foo(bar x: Int, y: String) async throws -> Bool
    /// ```
    var signatureString: String {
        let name = name.text

        // Parameters
        let params = signature.parameterClause.parameters.map { p -> String in
            let first = p.firstName.text
            let second = p.secondName?.text
            let type = p.type.description.trimmingCharacters(in: .whitespacesAndNewlines)
            if let second {
                return "\(first) \(second): \(type)"
            } else {
                return "\(first): \(type)"
            }
        }.joined(separator: ", ")

        // Effects
        let asyncStr = signature.effectSpecifiers?.asyncSpecifier != nil ? " async" : ""
        let throwsStr = signature.effectSpecifiers?.throwsSpecifier != nil ? " throws" : ""

        // Return type
        let returnType = signature.returnClause?.type
            .description.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Void"

        // Generics and where-clause
        let generics = genericParameterClause?.description.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let whereClause = genericWhereClause?.description.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        // Build
        var head = "func \(name)"
        if !generics.isEmpty { head += generics }
        head += "(\(params))\(asyncStr)\(throwsStr) -> \(returnType)"
        if !whereClause.isEmpty { head += " \(whereClause)" }
        return head
    }
}

public extension FunctionDeclSyntax {
    /// Canonical signature **key** for equality and lookup.
    ///
    /// Format:
    /// ```
    /// func <name>(label:Type,...) [async] [throws] ->ReturnType
    /// ```
    /// - Strips attributes and default values.
    /// - Normalizes whitespace.
    /// - Removes spaces inside type annotations.
    ///
    /// Example:
    /// ```swift
    /// func foo(bar x: Int = 0) -> String
    /// ```
    /// becomes
    /// ```
    /// func foo(bar:Int) ->String
    /// ```
    func canonicalSignatureKey() -> String {
        var parts: [String] = []

        parts.append("func")
        parts.append(name.text)

        // Parameters
        let items = signature.parameterClause.parameters.map { p -> String in
            let label = p.firstName.text
            let type = p.type.trimmedDescription.replacingOccurrences(of: " ", with: "")
            return "\(label):\(type)"
        }
        parts.append("(\(items.joined(separator: ",")))")

        // async / throws
        if signature.effectSpecifiers?.asyncSpecifier != nil { parts.append("async") }
        if signature.effectSpecifiers?.throwsSpecifier != nil { parts.append("throws") }

        // Return type
        if let ret = signature.returnClause?.type.trimmedDescription {
            parts.append("->\(ret.replacingOccurrences(of: " ", with: ""))")
        }

        return parts.joined(separator: " ")
    }
}
