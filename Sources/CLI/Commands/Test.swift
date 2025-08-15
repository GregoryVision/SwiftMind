//
//  TestCommand.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 18.06.2025.
//

import Foundation
import ArgumentParser
import os.log
import Core

// Что если output не пустой? Может сделать записть типа как DocInserter только TestsInserter?

@available(macOS 13.0, *)
struct Test: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Generate tests for a given Swift file")
    private static let logger = Logger(subsystem: "SwiftMind", category: "Test")
    
    @Argument(help: "The file to analyze")
    var filePath: String
    
    @Option(name: .shortAndLong, help: "Target function names to generate tests for")
    var functions: [String] = []
    
    @Option(name: .shortAndLong, help: "Custom user's prompt")
    var prompt: String?
    
    @Option(name: .customLong("context"), help: "Optional paths to additional files for context")
    var contextPaths: [String] = []
    
    @Option(name: .shortAndLong, help: "Path to output directory for generated tests")
    var output: String?
    
    @Flag(name: .long, help: "Enable verbose logging")
    var verbose: Bool = false
    
    func run() async throws {
        if verbose {
            Self.logger.info("Starting test generation for: \(filePath)")
        }
        let baseURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let resolvedFileURL = URL(fileURLWithPath: filePath, relativeTo: baseURL).standardized

        do {
            let (fileName, satitizedCode) = try prepareMainFile(at: resolvedFileURL, cfg: SwiftMind.config)
            let additional = try await loadAdditionalContext(from: contextPaths, base: baseURL)
            let testsDir = try resolveOutputDirectory(from: SwiftMind.config, resolvedFileURL: resolvedFileURL)
            try await generateTests(for: satitizedCode, fileName: fileName, additional: additional, cfg: SwiftMind.config)
        } catch let error as SwiftMindError {
            Self.logger.error("❌ Error: \(error.localizedDescription)")
            throw ExitCode.failure
        } catch {
            Self.logger.error("❌ Unexpected error: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
    
    private func prepareMainFile(at resolvedFileURL: URL, cfg: SwiftMindConfigProtocol) throws -> (String, String) {
        let (fileName, code) = try FileHelper.readCode(atAbsolutePath: resolvedFileURL.path)
        let satitizedCode = try PromptSanitizer.sanitize(code, maxLength: cfg.promptMaxLength)
        return (fileName, satitizedCode)
    }
    
    private func resolveOutputDirectory(from cfg: SwiftMindConfigProtocol, resolvedFileURL: URL) throws -> URL {
        return try FileHelper.resolveTestsDirectory(
            cliOverride: output,
            cfg: cfg,
            fileAbsolutePath: resolvedFileURL.path
        )
    }
    
    private func generateTests(for code: String,
                               fileName: String,
                               additional: String?,
                               cfg: SwiftMindConfigProtocol) async throws {
        if functions.isEmpty {
            Self.logger.info("Generating tests for entire file")
            let txt = try await SwiftMind.aiUseCases.generateTestsForEntireFile(code,
                                                                      customPrompt: prompt,
                                                                      additionalContext: additional,
                                                                      cfg: cfg)
            try saveTestFile(named: "\(fileName)Tests.swift",
                             content: txt,
                             to: cfg.testsDirectory.fileURL,
                             description: "Full file tests")
        } else {
            for fn in functions {
                Self.logger.info("Generating tests for function: \(fn)")
                let txt = try await SwiftMind.aiUseCases.generateTests(for: code,
                                                             functionName: fn,
                                                             customPrompt: prompt,
                                                             additionalContext: additional,
                                                             cfg: cfg)
                try saveTestFile(named: "\(fileName)_\(fn)Tests.swift",
                                 content: txt,
                                 to: cfg.testsDirectory.fileURL,
                                 description: "Tests for '\(fn)'")
            }
        }
    }
    
    /// Читает дополнительные файлы-контексты.
    /// - Parameters:
    ///   - paths:     Список путей (можно относительных и абсолютных)
    ///   - base:      Базовая директория, от которой «расправляем» относительные пути.
    /// - Returns:     Конкатенированное содержимое файлов (или пустая строка)
    private func loadAdditionalContext(from paths: [String], base: URL) async throws -> String? {
        guard !paths.isEmpty else { return nil }
        var result = ""
        
        for raw in paths {
            // 1. Строим абсолютный URL независимо от формата ввода
            let fileURL = URL(fileURLWithPath: raw, relativeTo: base).standardized
            
            // 2. Проверяем существование
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                print("⚠️ Context file not found: \(fileURL.path)")
                continue
            }
            
            // 3. Читаем и добавляем
            let fileContent = try String(contentsOf: fileURL)
            result += "\n\n" + fileContent
        }
        return result
    }
    
    private func saveTestFile(named fileName: String, content: String, to directory: URL, description: String) throws {
        let fileURL = try FileHelper.save(text: content, to: directory, fileName: fileName)
        print("✅ \(description) written to \(fileURL.path)")
    }
}
