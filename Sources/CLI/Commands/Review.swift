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

            // 1) Подготовка кода
            let (resolvedFileURL, _, sanitizedCode) = try prepareCode(from: filePath)
            let cfg = SwiftMind.config

            // 2) Сбор деклараций (для ожидания количества комментариев)
            let collector = try collectDeclarations(from: sanitizedCode)

            // Можно использовать набор типов из конфига; при необходимости сузить —
            // фильтровать collector.declarations по этим типам.
            let reviewKinds = cfg.documentationDeclarations
            let expectedCount = collector.declarations.count // TODO: при желании фильтровать по reviewKinds

            // 3) Генерация комментариев блоками, строго по порядку
            let generatedComments = try await SwiftMind.aiUseCases.reviewComments(
                for: sanitizedCode,
                declarations: reviewKinds,
                expectedCount: expectedCount,
                cfg: cfg,
                returnFormat: .blocks
            )

            try validateGeneratedComments(generatedComments)

            // 4) Fallback: если пользователь просит inline ИЛИ количество блоков не совпало
            if inline || generatedComments.count != expectedCount {
                Self.logger.warning("Inline mode or mismatch (expected \(expectedCount), got \(generatedComments.count)). Falling back to inline review.")
                try await fallbackInlineReview(sanitizedCode, to: resolvedFileURL, cfg: cfg)
                return
            }

            // 5) Вставка комментариев над декларациями через rewriter
            let (processed, skipped) = try applyReviewInserter(
                to: sanitizedCode,
                comments: generatedComments,
                fileURL: resolvedFileURL
            )

            // 6) Логи статистики
            logStatistics(
                collectorCount: expectedCount,
                commentsCount: generatedComments.count,
                processed: processed,
                skipped: skipped
            )

        } catch {
            try handle(error)
        }
    }

    private func prepareCode(from path: String) throws -> (URL, String, String) {
        let resolvedFileURL = FileHelper.resolve(filePath: path)
        try validateFile(at: resolvedFileURL)
        let (_, code) = try FileHelper.readCode(atAbsolutePath: resolvedFileURL.path)
        let cfg = SwiftMind.config
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

    private func fallbackInlineReview(_ code: String, to fileURL: URL, cfg: SwiftMindConfigProtocol) async throws {
        Self.logger.warning("Mismatch between declarations and review comments. Falling back to inline AI review.")
        let reviewedCode = try await SwiftMind.aiUseCases.reviewCode(code, cfg: cfg)
        try reviewedCode.write(to: fileURL, atomically: true, encoding: .utf8)
        Self.logger.info("✍️ Inline review comments inserted by AI into \(fileURL.path)")
    }

    private func applyReviewInserter(to code: String, comments: [String], fileURL: URL) throws -> (Int, Int) {
        let sourceFile = Parser.parse(source: code)
        let rewriter = DocInserter(docs: comments, skipExisting: true, commentPrefix: "// REVIEW:")
        let newTree = rewriter.visit(sourceFile)
        try "\(newTree)".write(to: fileURL, atomically: true, encoding: .utf8)
        return (rewriter.totalProcessed, rewriter.totalSkipped)
    }

    private func logStatistics(collectorCount: Int, commentsCount: Int, processed: Int, skipped: Int) {
        Self.logger.info("📊 Statistics:")
        Self.logger.info("  • Total declarations found: \(collectorCount)")
        Self.logger.info("  • Review comments generated: \(commentsCount)")
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

    private func validateGeneratedComments(_ comments: [String]) throws {
        for (index, comment) in comments.enumerated() {
            guard !comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ValidationError("Empty review comment at index \(index)")
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
