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
    private static let logger = Logger(subsystem: "SwiftMind", category: "Test")
    
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
            let cfg = SwiftMindConfig.load()
            let (resolvedFileURL, code, sanitizedCode) = try prepareCode(from: filePath)
            let collector = try collectDeclarations(from: sanitizedCode)
            
            let generatedDocs = try await generateDocs(for: sanitizedCode, style: style, cfg: cfg)
            try validateGeneratedDocs(generatedDocs)
            
            if generatedDocs.count != collector.declarations.count {
                try await fallbackInsertDocs(sanitizedCode, to: resolvedFileURL, cfg: cfg)
                return
            }
            
            let (processed, skipped) = try applyDocInserter(to: sanitizedCode, docs: generatedDocs, skipExisting: skipExisting, fileURL: resolvedFileURL)
            logStatistics(collectorCount: collector.declarations.count, docsCount: generatedDocs.count, processed: processed, skipped: skipped)
        } catch {
            try handle(error)
        }
    }
    
    private func prepareCode(from path: String) throws -> (URL, String, String) {
        let resolvedFileURL = FileHelper.resolve(filePath: path)
        try validateFile(at: resolvedFileURL)
        let (_, code) = try FileHelper.readCode(atAbsolutePath: resolvedFileURL.path)
        let cfg = SwiftMindConfig.load()
        let sanitizedCode = try PromptSanitizer.sanitize(code, maxLength: cfg.promptMaxLength)
        return (resolvedFileURL, code, sanitizedCode)
    }
    
    private func collectDeclarations(from code: String) throws -> DeclarationCollector {
        let sourceFile = Parser.parse(source: code)
        let collector = DeclarationCollector(viewMode: .sourceAccurate)
        collector.walk(sourceFile)
        Self.logger.info("Found \(collector.declarations.count) declarations")
        return collector
    }
    
    private func generateDocs(for code: String, style: DocumentationStyle, cfg: SwiftMindConfig) async throws -> [String] {
        let resultText = try await AIUseCases.generateDocumentation(for: code, style: style, declarations: cfg.documentationDeclarations, returnFormat: .separateBlocks)
        let generatedDocs = resultText.components(separatedBy: "\n\n").filter { !$0.isEmpty }
        return generatedDocs
    }
    
    private func fallbackInsertDocs(_ code: String, to fileURL: URL, cfg: SwiftMindConfig) async throws {
        Self.logger.warning("Mismatch between declarations and documentation blocks. Falling back to full code insertion.")
        let fullDocCode = try await AIUseCases.generateDocumentation(for: code, style: style, declarations: cfg.documentationDeclarations, returnFormat: .fullCode)
        try fullDocCode.write(to: fileURL, atomically: true, encoding: .utf8)
        Self.logger.info("✍️ Full documentation inserted by AI into \(fileURL.path)")
    }
    
    private func applyDocInserter(to code: String, docs: [String], skipExisting: Bool, fileURL: URL) throws -> (Int, Int) {
        let sourceFile = Parser.parse(source: code)
        let rewriter = DocInserter(docs: docs, skipExisting: skipExisting)
        let newTree = rewriter.visit(sourceFile)
        try "\(newTree)".write(to: fileURL, atomically: true, encoding: .utf8)
        return (rewriter.totalProcessed, rewriter.totalSkipped)
    }
    
    private func logStatistics(collectorCount: Int, docsCount: Int, processed: Int, skipped: Int) {
        Self.logger.info("📊 Statistics:")
        Self.logger.info("  • Total declarations found: \(collectorCount)")
        Self.logger.info("  • Documentation blocks generated: \(docsCount)")
        Self.logger.info("  • Processed: \(processed)")
        Self.logger.info("  • Skipped: \(skipped)")
    }
    
    private func handle(_ error: Error) throws {
        switch error {
        case let error as SwiftMindError:
            Self.logger.error("❌ Error: \(error.localizedDescription)")
            throw ExitCode.failure
        case let error as ValidationError:
            Self.logger.error("❌ Validation failed: \(error.description)")
            throw ExitCode.failure
        default:
            Self.logger.error("❌ Unexpected error: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
    
    private func validateGeneratedDocs(_ docs: [String]) throws {
        for (index, doc) in docs.enumerated() {
            guard !doc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ValidationError("Empty documentation at index \(index)")
            }
            
            // Проверка на минимальную длину
            guard doc.count > 10 else {
                throw ValidationError("Documentation too short at index \(index): '\(doc)'")
            }
        }
    }
    
    private func validateFile(at url: URL) throws {
        let path = url.path
        guard FileManager.default.fileExists(atPath: path) else {
            throw ValidationError("File not found: \(path)")
        }

        guard url.pathExtension == "swift" else {
            throw ValidationError("Only Swift files (.swift) are supported")
        }

        guard FileManager.default.isReadableFile(atPath: path) else {
            throw ValidationError("File is not readable: \(path)")
        }
    }
}
