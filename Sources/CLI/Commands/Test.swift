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

    
    func run() async throws {
        Self.logger.info("Starting test generation for: \(filePath)")
        
        let baseURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

        do {
            let (resolvedFileURL, fileName, satitizedCode) = try CodeProcessingService.prepareCode(from: filePath,
                                                                                                   promptMaxLength: SwiftMindCLI.config.promptMaxLength)
            let additional = try await FileHelper.loadAdditionalContext(from: contextPaths,
                                                                        base: baseURL)
            let testsDir = try FileHelper.resolveTestsDirectory(
                cliOverride: output,
                cfg: SwiftMindCLI.config,
                fileAbsolutePath: resolvedFileURL.path
            )
            try await generateTests(for: satitizedCode,
                                    fileName: fileName,
                                    additional: additional,
                                    testsDir: testsDir)
        } catch {
            try SwiftMindError.handle(error, logger: Self.logger)
        }
    }
    
    private func generateTests(for code: String,
                               fileName: String,
                               additional: String?,
                               testsDir: URL) async throws {
        if functions.isEmpty {
            Self.logger.info("Generating tests for entire file")
            let txt = try await SwiftMindCLI.aiUseCases.generateTests.forEntireFile(code: code,
                                                                      customPrompt: prompt,
                                                                      additionalContext: additional)
            try saveTestFile(named: "\(fileName)Tests.swift",
                             content: txt,
                             to: testsDir,
                             description: "Full file tests")
        } else {
            for fn in functions {
                Self.logger.info("Generating tests for function: \(fn)")
                let txt = try await SwiftMindCLI.aiUseCases.generateTests.forFunction(code: code,
                                                             functionName: fn,
                                                             customPrompt: prompt,
                                                             additionalContext: additional)
                try saveTestFile(named: "\(fileName)_\(fn)Tests.swift",
                                 content: txt,
                                 to: testsDir,
                                 description: "Tests for '\(fn)'")
            }
        }
    }
    
    
    private func saveTestFile(named fileName: String, content: String, to directory: URL, description: String) throws {
        let fileURL = try FileHelper.save(text: content, to: directory, fileName: fileName)
        Self.logger.info("✅ \(description) written to \(fileURL.path)")
    }
}
