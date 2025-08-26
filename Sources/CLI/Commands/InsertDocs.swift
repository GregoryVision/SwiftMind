//
//  InsertDocsCommand.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 18.06.2025.
//

import Foundation
import ArgumentParser
import SwiftSyntax
import os.log
import Core

@available(macOS 13.0, *)
struct InsertDocs: AsyncParsableCommand {
    
    static let configuration = CommandConfiguration(abstract: "Insert documentation comments directly into Swift file")
    private static let logger = Logger(subsystem: "SwiftMind", category: "InsertDocs")
    
    @Argument(help: "The file to document")
    var filePath: String
    
    @Argument(help: "Target function names to generate docs for")
    var functions: [String] = []
    
    @Option(name: .long, help: "Skip functions that already have documentation")
    var skipExisting: Bool = false

    @Option(name: .long, help: "Documentation style (brief/detailed)")
    var style: DocumentationStyle = .detailed
    
    func run() async throws {
        guard !functions.isEmpty else {
            throw ValidationError("Please specify at least one function to review.")
        }
        do {
            Self.logger.info("Starting documentation insertion for: \(filePath)")
            let codeRes = try CodeProcessingService.prepareCode(from: filePath)
            
            let commentsBySig = try await generateDocsMap(for: codeRes.sanitizedCode,
                                                          style: style,
                                                          targets: functions,
                                                          cfg: SwiftMindCLI.config)
            
            let (processed, skipped) = try FunctionDocInserter.apply(
                to: codeRes.sanitizedCode,
                commentsBySignature: commentsBySig,
                skipExisting: skipExisting,
                kind: .documentation,
                writeTo: codeRes.resolvedFileURL
            )
            
            Self.logger.logStatistics(docsCount: commentsBySig.count, processed: processed, skipped: skipped)
        } catch {
            try SwiftMindError.handle(error, logger: Self.logger)
        }
    }
    
    private func generateDocsMap(for code: String,
                                 style: DocumentationStyle,
                                 targets: [String],
                                 cfg: SwiftMindConfigProtocol) async throws -> [String: String] {
        // Собрали все функции и подготовили мапу "сигнатура → текст"
        let collector = FunctionCollector.collect(from: code, topLevelOnly: false)

        var result: [String:String] = [:]

        // Если targets пуст — берём все функции; иначе — только выбранные
        let functionNodes: [FunctionDeclSyntax]
        if targets.isEmpty {
            functionNodes = collector.functions
        } else {
            functionNodes = targets.flatMap { collector.functionDecls(target: $0) }
        }
        
        for fn in functionNodes {
            let sig = fn.signatureString
            let functionSource = String(fn.description)
            let doc = try await SwiftMindCLI.aiUseCases.generateDocs.generateSingleFunctionDoc(
                functionSource: functionSource,
                style: style,
                promptMaxLength: cfg.promptMaxLength
            )

            result[sig] = doc
        }

        return result
    }
    
    private func validateGeneratedDocs(_ docs: [String]) throws {
        for (index, doc) in docs.enumerated() {
            guard !doc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ValidationError("Empty documentation at index \(index)")
            }
            
            guard doc.count > 10 else {
                throw ValidationError("Documentation too short at index \(index): '\(doc)'")
            }
        }
    }
}
