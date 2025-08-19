//
//  ReviewCommand.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 11.08.2025.
//

import Foundation
import ArgumentParser
import os.log
import Core
import SwiftParser

struct Review: AsyncParsableCommand {
    
    static let configuration = CommandConfiguration(
        abstract: "Perform AI code review and insert comments or print suggestions"
    )
    private static let logger = Logger(subsystem: "SwiftMind", category: "Review")

    @Argument(help: "The file to review")
    var filePath: String

    @Flag(name: .shortAndLong, help: "Insert review comments directly into the code")
    var inline: Bool = false

    func run() async throws {
        do {
            Self.logger.info("Starting code review for: \(filePath)")

            let cfg = SwiftMindCLI.config
            let (resolvedFileURL, _, sanitizedCode) = try CodeProcessingService.prepareCode(from: filePath,
                                                                                            promptMaxLength: SwiftMindCLI.config.promptMaxLength)

            let collector = try DeclarationCollector.collectDeclarations(from: sanitizedCode)
            Self.logger.info("Found \(collector.declarations.count) declarations")

            let reviewKinds = cfg.documentationDeclarations
            let expectedCount = collector.declarations.count

            let generatedComments = try await SwiftMindCLI.aiUseCases.reviewCode.comments(
                code: sanitizedCode,
                declarations: reviewKinds,
                expectedCount: expectedCount,
                returnFormat: .blocks
            )

            try validateGeneratedComments(generatedComments)

            if inline || generatedComments.count != expectedCount {
                Self.logger.warning("Inline mode or mismatch (expected \(expectedCount), got \(generatedComments.count)). Falling back to inline review.")
                try await fallbackInlineReview(sanitizedCode, to: resolvedFileURL, cfg: cfg)
                return
            }

            let (processed, skipped) = try DocInserter.applyDocInserter(
                to: sanitizedCode,
                docs: generatedComments,
                skipExisting: true,
                fileURL: resolvedFileURL,
                kind: .review)

            Self.logger.logStatistics(
                collectorCount: expectedCount,
                commentsCount: generatedComments.count,
                processed: processed,
                skipped: skipped)

        } catch {
            try SwiftMindError.handle(error, logger: Self.logger)
        }
    }

    private func fallbackInlineReview(_ code: String, to fileURL: URL, cfg: SwiftMindConfigProtocol) async throws {
        Self.logger.warning("Mismatch between declarations and review comments. Falling back to inline AI review.")
        let reviewedCode = try await SwiftMindCLI.aiUseCases.reviewCode.review(code: code)
        try reviewedCode.write(to: fileURL, atomically: true, encoding: .utf8)
        Self.logger.info("✍️ Inline review comments inserted by AI into \(fileURL.path)")
    }

    private func validateGeneratedComments(_ comments: [String]) throws {
        for (index, comment) in comments.enumerated() {
            guard !comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ValidationError("Empty review comment at index \(index)")
            }
        }
    }
}
