//
//  ExplainCommand.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 21.07.2025.
//

import Core
import Foundation
import ArgumentParser

@available(macOS 13.0, *)
struct Explain: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Explain what Swift code does")
    
    @Argument(help: "The file to explain")
    var filePath: String
    
    func run() async throws {
        let baseURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let resolvedFileURL = URL(fileURLWithPath: filePath, relativeTo: baseURL).standardized
        
        do {
            let code = try prepareCode(from: resolvedFileURL)
            let explanation = try await generateExplanation(for: code, cfg: SwiftMind.config)
            printExplanation(explanation)
        } catch let error as SwiftMindError {
            print("❌ Error: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
    
    private func prepareCode(from fileURL: URL) throws -> String {
        let (_, code) = try FileHelper.readCode(atAbsolutePath: fileURL.path)
        return code
    }
    
    private func generateExplanation(for code: String, cfg: SwiftMindConfigProtocol) async throws -> String {
        return try await SwiftMind.aiUseCases.explainCode(code, cfg: cfg)
    }
    
    private func printExplanation(_ explanation: String) {
        print("📝 Code Explanation:")
        print(explanation)
    }
}
