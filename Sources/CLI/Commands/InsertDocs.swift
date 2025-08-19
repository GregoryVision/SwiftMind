//
//  InsertDocsCommand.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 18.06.2025.
//

import Foundation
import ArgumentParser
import os.log
import Core
import SwiftSyntax
import SwiftParser

@available(macOS 13.0, *)
struct InsertDocs: AsyncParsableCommand {
    
    static let configuration = CommandConfiguration(abstract: "Insert documentation comments directly into Swift file")
    private static let logger = Logger(subsystem: "SwiftMind", category: "InsertDocs")
    
    @Argument(help: "The file to document")
    var filePath: String
    
    @Option(name: .long, help: "Skip functions that already have documentation")
    var skipExisting: Bool = false

    @Option(name: .long, help: "Documentation style (brief/detailed)")
    var style: DocumentationStyle = .brief
    
    @Option(help: "The output format for generated documentation.")
    var returnFormat: DocumentationReturnFormat = .separateBlocks
    
    func run() async throws {
        do {
            Self.logger.info("Starting documentation insertion for: \(filePath)")
            let (resolvedFileURL, _, sanitizedCode) = try CodeProcessingService.prepareCode(from: filePath,
                                                                                            promptMaxLength: SwiftMindCLI.config.promptMaxLength)
            let collector = try DeclarationCollector.collectDeclarations(from: sanitizedCode)
            Self.logger.info("Found \(collector.declarations.count) declarations")
            
            let generatedDocs = try await generateDocs(for: sanitizedCode, style: style, cfg: SwiftMindCLI.config)
            try validateGeneratedDocs(generatedDocs)
            
            if generatedDocs.count != collector.declarations.count {
                try await fallbackInsertDocs(sanitizedCode, to: resolvedFileURL, cfg: SwiftMindCLI.config)
                return
            }
            
            let (processed, skipped) = try DocInserter.applyDocInserter(to: sanitizedCode,
                                                                        docs: generatedDocs,
                                                                        skipExisting: skipExisting,
                                                                        fileURL: resolvedFileURL,
                                                                        kind: .documentation)
            Self.logger.logStatistics(collectorCount: collector.declarations.count,
                                      docsCount: generatedDocs.count,
                                      processed: processed,
                                      skipped: skipped)
        } catch {
            try SwiftMindError.handle(error, logger: Self.logger)
        }
    }
    
    private func generateDocs(for code: String, style: DocumentationStyle, cfg: SwiftMindConfigProtocol) async throws -> [String] {
        let generatedDocs = try await SwiftMindCLI.aiUseCases.generateDocs.generateBlocks(for: code,
                                                                                 style: style,
                                                                                 declarations: cfg.documentationDeclarations)
        return generatedDocs
    }
    
    private func fallbackInsertDocs(_ code: String, to fileURL: URL, cfg: SwiftMindConfigProtocol) async throws {
        Self.logger.warning("Mismatch between declarations and documentation blocks. Falling back to full code insertion.")
        let fullDocCode = try await SwiftMindCLI.aiUseCases.generateDocs.generateFullCode(for: code,
                                                                                  style: style,
                                                                                  declarations: cfg.documentationDeclarations)
        try fullDocCode.write(to: fileURL, atomically: true, encoding: .utf8)
        Self.logger.info("✍️ Full documentation inserted by AI into \(fileURL.path)")
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
