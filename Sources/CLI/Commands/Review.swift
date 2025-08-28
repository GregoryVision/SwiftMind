//
//  ReviewCommand.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 11.08.2025.
//

import Foundation
import ArgumentParser
import SwiftSyntax
import os.log
import Core

struct Review: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "AI review for selected Swift functions and inline // REVIEW: comments"
    )

    private static let logger = Logger(subsystem: "SwiftMind", category: "Review")

    @Argument(help: "Path to the Swift file to review")
    var filePath: String

    @Argument(help: "Target functions to review (name or full signature). At least one is required.")
    var functions: [String]

    @Option(name: .long, help: "When true, don't modify the file — just print the generated review blocks")
    var dryRun: Bool = false

    @Option(name: .long, help: "Skip functions that already contain a REVIEW comment")
    var skipExisting: Bool = true

    func run() async throws {
        guard !functions.isEmpty else {
            throw ValidationError("Please specify at least one function to review.")
        }

        do {
            print("Starting function review for: \(filePath)")
            
            let codeRes = try CodeProcessingService.prepareCode(from: filePath)

            let commentsBySig = try await generateReviewMap(for: codeRes.sanitizedCode,
                                                            targets: functions,
                                                            cfg: SwiftMindCLI.config)

            let (_, _) = try FunctionDocInserter.apply(
                to: codeRes.sanitizedCode,
                commentsBySignature: commentsBySig,
                skipExisting: skipExisting,
                kind: .review,
                writeTo: codeRes.resolvedFileURL
            )

            print("✅ Review comments inserted into \(codeRes.resolvedFileURL.path)")
        } catch {
            try SwiftMindError.handle(error)
        }
    }
    
    private func generateReviewMap(for code: String,
                                   targets: [String],
                                   cfg: SwiftMindConfigProtocol) async throws -> [String: String] {
        let collector = FunctionCollector.collect(from: code, topLevelOnly: false)
        var result: [String: String] = [:]

        let functionNodes: [FunctionDeclSyntax]
        if targets.isEmpty {
            functionNodes = collector.functions
        } else {
            functionNodes = targets.flatMap { collector.functionDecls(target: $0) }
        }

        for fn in functionNodes {
            let sig = fn.signatureString
            let src = String(fn.description)

            let review = try await SwiftMindCLI.aiUseCases.reviewCode.generateSingleFunctionReview(
                functionSource: src,
                functionSignature: sig,
                promptMaxLength: cfg.promptMaxLength
            ).trimmingCharacters(in: .whitespacesAndNewlines)

            result[sig] = review
        }

        return result
    }

    private func validateGeneratedComments(_ comments: [String]) throws {
        for (index, comment) in comments.enumerated() {
            guard !comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ValidationError("Empty review comment at index \(index)")
            }
        }
    }
}
