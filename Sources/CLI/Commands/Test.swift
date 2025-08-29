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

/// CLI subcommand that generates unit tests for target Swift functions in a file.
///
/// Uses SwiftMind AI back end to synthesize XCTest code. If no specific function
/// names are provided, tests are generated for all discovered functions.
struct Test: AsyncParsableCommand {
    /// Command configuration shown in `--help`.
    static let configuration = CommandConfiguration(
        abstract: "Generate tests for a given Swift file"
    )

    /// Subsystem logger for the `Test` command.
    private static let logger = Logger(subsystem: "SwiftMind", category: "Test")
    
    /// Path to the Swift source file to analyze.
    @Argument(help: "The file to analyze")
    var filePath: String
    
    /// Optional list of function names to target. If empty, all functions are processed.
    @Argument(help: "Target function names to generate tests for")
    var functions: [String] = []
    
    /// Optional custom prompt to steer AI test generation.
    @Option(name: .shortAndLong,
            help: "Custom user's prompt")
    var prompt: String?
    
    // Previously: Optional paths to additional files for context.
    // If you bring this back, translate/help like:
    // @Option(name: .customLong("context"),
    //         parsing: .upToNextOption,
    //         help: "Optional paths to additional files for additional context")
    // var contextPaths: [String] = []

    /// Optional output directory for the generated test files.
    /// If not provided, the default location is resolved from configuration.
    @Option(name: .shortAndLong,
            help: "Path to output directory for generated tests")
    var output: String?

    /// Entry point for the `test` subcommand.
    ///
    /// - Throws: Rethrows underlying errors after standardized handling.
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
            try await generateTests(
                for: codeProcessingResult.sanitizedCode,
                fileName: codeProcessingResult.fileName,
                testsDir: testsDir,
                moduleName: moduleName
            )
        } catch {
            try SwiftMindError.handle(error)
        }
    }
    
    /// Generates tests for discovered or explicitly specified functions.
    ///
    /// - Parameters:
    ///   - code: Sanitized Swift source code.
    ///   - fileName: Base file name (used for test file naming).
    ///   - testsDir: Destination directory for test files.
    ///   - moduleName: Optional module name inferred from the code (reserved for future use).
    private func generateTests(
        for code: String,
        fileName: String,
        testsDir: URL,
        moduleName: String?
    ) async throws {
        let collector = FunctionCollector.collect(from: code, topLevelOnly: false)
        Self.logger.info("Found \(collector.functions.count) functions")

        if functions.isEmpty {
            // All discovered functions
            for fn in collector.functions {
                let fnSign = fn.signatureString
                try await generateAndSaveTests(
                    code: code,
                    fileName: fileName,
                    testsDir: testsDir,
                    targetFuncName: fn.name.text,
                    targetFuncSignature: fnSign
                )
            }
        } else {
            // Only user-specified functions
            for fn in functions {
                let funcSignatures = collector.functionSignatures(named: fn)
                for funcSignature in funcSignatures {
                    try await generateAndSaveTests(
                        code: code,
                        fileName: fileName,
                        testsDir: testsDir,
                        targetFuncName: fn,
                        targetFuncSignature: funcSignature
                    )
                }
            }
        }
    }
    
    /// Common helper that requests AI-generated tests and writes them to disk.
    ///
    /// - Parameters:
    ///   - code: The full Swift source code used as context.
    ///   - fileName: Base file name (used to build the test file name).
    ///   - testsDir: Destination directory for test files.
    ///   - targetFuncName: Function name to generate tests for.
    ///   - targetFuncSignature: Function signature string to give the model more context.
    private func generateAndSaveTests(
        code: String,
        fileName: String,
        testsDir: URL,
        targetFuncName: String,
        targetFuncSignature: String
    ) async throws {
        print("Generating tests for function: \(targetFuncName)")
        let ollamaGeneratedTestCode = try await SwiftMindCLI.aiUseCases.generateTests.forFunction(
            code: code,
            funcName: targetFuncName,
            funcSign: targetFuncSignature,
            promptMaxLength: SwiftMindCLI.config.promptMaxLength,
            customPrompt: prompt
        )
        try saveTestFile(
            named: "\(fileName)_\(targetFuncName)Tests.swift",
            content: ollamaGeneratedTestCode.cleanGeneratedCode(),
            to: testsDir,
            description: "Tests for '\(targetFuncName)'"
        )
    }
    
    /// Persists a generated test file to disk and prints a success message.
    ///
    /// - Parameters:
    ///   - fileName: Output file name (e.g., `MyFile_myFuncTests.swift`).
    ///   - content: Swift test source code to write.
    ///   - directory: Destination directory URL.
    ///   - description: Short human-friendly description for console output.
    private func saveTestFile(
        named fileName: String,
        content: String,
        to directory: URL,
        description: String
    ) throws {
        let fileURL = try FileHelper.save(text: content, to: directory, fileName: fileName)
        print("✅ \(description) written to \(fileURL.path)")
    }
}
