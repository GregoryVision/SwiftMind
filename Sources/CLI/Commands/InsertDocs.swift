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

/// Inserts documentation comments directly into a Swift file for selected or all functions.
struct InsertDocs: AsyncParsableCommand {
    
    /// Command configuration shown in `--help`.
    static let configuration = CommandConfiguration(
        abstract: "Insert documentation comments directly into Swift file"
    )
    
    /// Subsystem logger for the `InsertDocs` command.
    private static let logger = Logger(subsystem: "SwiftMind", category: "InsertDocs")
    
    /// Path to the Swift file to document.
    @Argument(help: "The file to document")
    var filePath: String
    
    /// Target function names to generate docs for. If empty, all functions are processed.
    @Argument(help: "Target function names to generate docs for")
    var functions: [String] = []
    
    /// When true, functions that already have documentation are skipped.
    @Option(name: .long, help: "Skip functions that already have documentation")
    var skipExisting: Bool = false

    /// Documentation style to generate (brief/detailed).
    @Option(name: .long, help: "Documentation style (brief/detailed)")
    var style: DocumentationStyle = .detailed
    
    /// Entry point for the `insert-docs` subcommand.
    func run() async throws {
        do {
            print("Starting documentation insertion for: \(filePath)")
            let codeRes = try CodeProcessingService.prepareCode(from: filePath)
            
            let commentsBySig = try await generateDocsMap(
                for: codeRes.sanitizedCode,
                style: style,
                targets: functions,
                cfg: SwiftMindCLI.config
            )
            
            // Validate generated blocks before applying.
            try validateGeneratedDocs(Array(commentsBySig.values))
            
            let (processed, skipped) = try FunctionDocInserter.apply(
                to: codeRes.sanitizedCode,
                commentsBySignature: commentsBySig,
                skipExisting: skipExisting,
                kind: .documentation,
                writeTo: codeRes.resolvedFileURL
            )
            print("✅ Documentation inserted into: \(filePath)")
            Self.logger.logStatistics(docsCount: commentsBySig.count, processed: processed, skipped: skipped)
        } catch {
            try SwiftMindError.handle(error)
        }
    }
    
    /// Builds a map `signature -> documentation` for the requested targets.
    ///
    /// - Parameters:
    ///   - code: Full Swift source (sanitized).
    ///   - style: Desired documentation style.
    ///   - targets: Function names or signatures to document. If empty, all functions are used.
    ///   - cfg: Global configuration (prompt limits, etc.).
    /// - Returns: Dictionary of canonical function signatures to generated documentation strings.
    private func generateDocsMap(
        for code: String,
        style: DocumentationStyle,
        targets: [String],
        cfg: SwiftMindConfigProtocol
    ) async throws -> [String: String] {
        // Collect all functions and prepare the "signature → text" map.
        let collector = FunctionCollector.collect(from: code, topLevelOnly: false)

        var result: [String:String] = [:]

        // If targets is empty — use all functions; otherwise — only selected.
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
            .trimmingCharacters(in: .whitespacesAndNewlines)

            result[sig] = doc
        }

        return result
    }
    
    /// Validates generated documentation blocks for minimal quality.
    /// - Parameter docs: Array of documentation strings.
    /// - Throws: `ValidationError` if a doc is empty or too short.
    private func validateGeneratedDocs(_ docs: [String]) throws {
        for (index, doc) in docs.enumerated() {
            let trimmed = doc.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw ValidationError("Empty documentation at index \(index)")
            }
            guard trimmed.count > 10 else {
                throw ValidationError("Documentation too short at index \(index): '\(trimmed)'")
            }
        }
    }
}
