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
    public private(set) var functions: [FunctionDeclSyntax] = []
    private let topLevelOnly: Bool
    private let logger = Logger(subsystem: "SwiftMind", category: "FunctionCollector")

    /// - Parameter topLevelOnly: если true — собирать только топ-левел функции (вне типов/экстеншенов)
    public init(topLevelOnly: Bool = false,
                viewMode: SyntaxTreeViewMode = .sourceAccurate) {
        self.topLevelOnly = topLevelOnly
        super.init(viewMode: viewMode)
    }

    public override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        if !topLevelOnly || isTopLevel(node) {
            functions.append(node)
        }
        return .visitChildren
    }

    /// Собрать функции из сырого исходника
    public static func collect(from source: String,
                               topLevelOnly: Bool = false) -> FunctionCollector {
        let file = Parser.parse(source: source)
        let v = FunctionCollector(topLevelOnly: topLevelOnly, viewMode: .sourceAccurate)
        v.walk(file)
        return v
    }

    // MARK: - Helpers

    /// Является ли функция топ-левел (не внутри типа/extension)
    private func isTopLevel(_ node: SyntaxProtocol) -> Bool {
        // Для топ-левел функций родительская цепочка: FunctionDeclSyntax
        // -> CodeBlockItemSyntax -> SourceFileSyntax
        var p = node.parent
        while let parent = p {
            if parent.is(SourceFileSyntax.self) { return true }
            // Если встретили декларацию типа — значит функция вложенная
            if parent.is(DeclSyntax.self) && !parent.is(SourceFileSyntax.self) {
                return false
            }
            p = parent.parent
        }
        return false
    }
}

// MARK: - Удобные представления

public extension FunctionDeclSyntax {
    /// Декларация без тела (все модификаторы/атрибуты сохраняются)
    var declarationString: String {
        self.with(\.body, nil).trimmedDescription
    }

    /// Полный текст функции (включая тело)
    var fullText: String {
        self.trimmedDescription
    }
}

extension FunctionCollector {
    /// Возвращает точную сигнатуру функции по имени (без тела).
    /// Если несколько перегрузок – вернёт все.
    public func functionSignatures(named name: String) -> [String] {
        functions.compactMap { fnDecl in
            guard fnDecl.name.text == name else { return nil }
            
            // Берём весь заголовок (attributes + modifiers + func keyword + identifier + signature)
            let header = fnDecl.trimmedDescription
            
            // Обрезаем тело (если есть)
            if let body = fnDecl.body {
                let bodyRange = body.trimmedDescription
                if let range = header.range(of: bodyRange) {
                    return String(header[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            return header
        }
    }
    
    /// Возвращает первую сигнатуру функции по имени
    public func firstFunctionSignature(named name: String) -> String? {
        return functionSignatures(named: name).first
    }
}

extension FunctionCollector {
    /// Универсальный поиск: принимает либо имя, либо полную сигнатуру/заголовок.
    /// - Если это имя — вернёт все перегрузки по имени.
    /// - Если это сигнатура — вернёт точные совпадения по канонической сигнатуре.
    /// - Если это «заголовок» без `func` или с обрезкой — попробует prefix-match по канонизированной сигнатуре.
    public func functionDecls(target: String) -> [FunctionDeclSyntax] {
        let t = target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return [] }
        
        // 1) Похоже на сигнатуру? (есть скобки параметров/генерики/throws/-> или начинается с func)
        if t.isProbablySignatureLike {
            // Точное совпадение канонической сигнатуры
            let key = t.canonicalizedSignatureKey()
            let exact = functions.filter { $0.canonicalSignatureKey() == key }
            if !exact.isEmpty { return exact }
            
            // Пробуем prefix-match (пользователь мог передать укороченный заголовок)
            return functions.filter { $0.canonicalSignatureKey().hasPrefix(key) }
        }
        
        // 2) Иначе считаем, что это имя
        return functions.filter { $0.name.text == t }
    }
    /// Все функции с данным именем (все перегрузки)
    public func functionDecls(named name: String) -> [FunctionDeclSyntax] {
        functions.filter { $0.name.text == name }
    }

    /// Поиск по канонической сигнатуре (если пользователь передал полную сигнатуру)
    public func functionDecls(matching target: String) -> [FunctionDeclSyntax] {
        let normalizedTarget = target.canonicalizedSignatureKey()
        return functions.filter { $0.canonicalSignatureKey() == normalizedTarget }
    }
}

extension FunctionDeclSyntax {
    /// Канонический ключ сигнатуры: func <name>(label:Type,...) [async] [throws] -> ReturnType
    /// без атрибутов, без значений по умолчанию, с нормализованными пробелами
    public func canonicalSignatureKey() -> String {
        var parts: [String] = []

        parts.append("func")
        parts.append(name.text)

        // Параметры
        let items = signature.parameterClause.parameters.map { p -> String in
            let label = p.firstName.text
            let type = p.type.trimmedDescription.replacingOccurrences(of: " ", with: "")
            return "\(label):\(type)"
        }
        parts.append("(\(items.joined(separator: ",")))")

        // async / throws
        if signature.effectSpecifiers?.asyncSpecifier != nil { parts.append("async") }
        if signature.effectSpecifiers?.throwsSpecifier != nil { parts.append("throws") }

        // return type
        if let ret = signature.returnClause?.type.trimmedDescription {
            parts.append("->\(ret.replacingOccurrences(of: " ", with: ""))")
        }

        return parts.joined(separator: " ")
    }
}

private extension String {
    /// Нормализация пользовательского ввода под тот же формат ключа
    func canonicalizedSignatureKey() -> String {
        self
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: " ", with: " ") // one space
            .replacingOccurrences(of: " : ", with: ":")
            .replacingOccurrences(of: " -> ", with: "->")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    /// Грубая эвристика «похоже на сигнатуру/заголовок», а не просто имя.
    var isProbablySignatureLike: Bool {
        // Начинается с `func` — точно сигнатура
        if self.hasPrefix("func") { return true }
        
        // Есть круглые скобки (параметры) или generics `<...>`
        if self.contains("(") && self.contains(")") { return true }
        if self.contains("<") && self.contains(">") { return true }
        
        // Наличие меток async/throws/-> тоже сигнал
        if self.contains("->") || self.contains("throws") || self.contains("rethrows") || self.contains("async") {
            return true
        }
        
        // Есть where-ограничения
        if self.contains(" where ") { return true }
        
        return false
    }
}
