//
//  FunctionDeclSyntax+signatureString.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 25.08.2025.
//

import Foundation
import SwiftSyntax

public extension FunctionDeclSyntax {
    /// Каноническая сигнатура: устойчива к форматированию, без атрибутов/дефолтов.
    var signatureString: String {
        let name = name.text

        // Параметры
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

        // Эффекты
        let asyncStr = signature.effectSpecifiers?.asyncSpecifier != nil ? " async" : ""
        let throwsStr = signature.effectSpecifiers?.throwsSpecifier != nil ? " throws" : ""

        // Возврат
        let returnType = signature.returnClause?.type
            .description.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Void"

        // Дженерики/where — по желанию включать:
        let generics = genericParameterClause?.description.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let whereClause = genericWhereClause?.description.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        // Собираем
        var head = "func \(name)"
        if !generics.isEmpty { head += generics }
        head += "(\(params))\(asyncStr)\(throwsStr) -> \(returnType)"
        if !whereClause.isEmpty { head += " \(whereClause)" }
        return head
    }
}
