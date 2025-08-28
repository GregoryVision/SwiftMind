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
    
    @Argument(help: "Target function names to generate tests for")
    var functions: [String] = []
    
    @Option(name: .shortAndLong,
            help: "Custom user's prompt")
    var prompt: String?
    
//    @Option(name: .customLong("context"),
//            parsing: .upToNextOption,
//            help: "Optional paths to additional files for context")
//    var contextPaths: [String] = []
    
    @Option(name: .shortAndLong,
            help: "Path to output directory for generated tests")
    var output: String?

    
    func run() async throws {
        do {
            Self.logger.info("Starting test generation for: \(filePath)")
            let codeProcessingResult = try CodeProcessingService.prepareCode(from: filePath)
            let testsDir = try FileHelper.resolveTestsDirectory(
                cliOverride: output,
                cfg: SwiftMindCLI.config,
                fileAbsolutePath: codeProcessingResult.resolvedFileURL.path
            )
            let moduleName = CodeProcessingService.extractModuleName(from: codeProcessingResult.sanitizedCode)
            try await generateTests(for: codeProcessingResult.sanitizedCode,
                                    fileName: codeProcessingResult.fileName,
                                    testsDir: testsDir,
                                    moduleName: moduleName)
        } catch {
            try SwiftMindError.handle(error)
        }
    }
    
    private func generateTests(for code: String,
                               fileName: String,
                               testsDir: URL,
                               moduleName: String?) async throws {
        let collector = FunctionCollector.collect(from: code, topLevelOnly: false)
        Self.logger.info("Found \(collector.functions.count) functions")
        if functions.isEmpty {
            for fn in collector.functions {
                let fnSign = fn.signatureString
                print("Generating tests for function: \(fnSign)")
                let ollamaGeneratedTestCode = try await SwiftMindCLI.aiUseCases.generateTests.forFunction(code: code,
                                                                                                          funcName: fn.name.text,
                                                                                                          funcSign: fnSign,
                                                                                                          promptMaxLength: SwiftMindCLI.config.promptMaxLength,
                                                                                                          customPrompt: prompt)
                try saveTestFile(named: "\(fileName)_\(fn.name.text)Tests.swift",
                                 content: ollamaGeneratedTestCode.cleanGeneratedCode(),
                                 to: testsDir,
                                 description: "Tests for '\(fn)'")
            }
        } else {
            for fn in functions {
                Self.logger.info("Found \(collector.functions.count) functions")
                let funcSignatures = collector.functionSignatures(named: fn)
                for funcSignature in funcSignatures {
                    print("Generating tests for function: \(fn)")
                    let ollamaGeneratedTestCode = try await SwiftMindCLI.aiUseCases.generateTests.forFunction(code: code,
                                                                                                              funcName: fn,
                                                                                                              funcSign: funcSignature,
                                                                                                              promptMaxLength: SwiftMindCLI.config.promptMaxLength,
                                                                                                              customPrompt: prompt)
                    try saveTestFile(named: "\(fileName)_\(fn)Tests.swift",
                                     content: ollamaGeneratedTestCode.cleanGeneratedCode(),
                                     to: testsDir,
                                     description: "Tests for '\(fn)'")
                }
            }
        }
    }
    
    private func saveTestFile(named fileName: String, content: String, to directory: URL, description: String) throws {
        let fileURL = try FileHelper.save(text: content, to: directory, fileName: fileName)
        print("✅ \(description) written to \(fileURL.path)")
    }
}

extension String {
    func cleanGeneratedCode() -> String {
        self
            .replacingOccurrences(of: "```swift", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
