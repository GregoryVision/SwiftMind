//
//  AIUseCases.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 06.06.2025.
//

import Foundation
import os.log

/// Defines the set of AI-powered use cases available in SwiftMind.
public protocol AIUseCasesProtocol {
    /// Generates unit tests for Swift functions.
    var generateTests: GenerateTestsUseCase { get }
    /// Reviews Swift code and produces inline feedback.
    var reviewCode: ReviewCodeUseCase { get }
    /// Explains the behavior of a Swift function.
    var explainCode: ExplainCodeUseCase { get }
    /// Generates documentation comments for Swift declarations.
    var generateDocs: GenerateDocumentationUseCase { get }
    /// Fixes code
    var fixCode: FixCodeUseCase { get }
}

/// Concrete container of all AI use cases.
///
/// This acts as a single access point for the CLI and can be easily
/// replaced with mocks in tests.
public struct AIUseCases: AIUseCasesProtocol {
    public let generateTests: GenerateTestsUseCase
    public let reviewCode: ReviewCodeUseCase
    public let explainCode: ExplainCodeUseCase
    public let generateDocs: GenerateDocumentationUseCase
    public let fixCode: FixCodeUseCase

    /// Initializes the container with specific implementations.
    public init(
        generateTests: GenerateTestsUseCase,
        reviewCode: ReviewCodeUseCase,
        explainCode: ExplainCodeUseCase,
        generateDocs: GenerateDocumentationUseCase,
        fixCode: FixCodeUseCase
    ) {
        self.generateTests = generateTests
        self.reviewCode = reviewCode
        self.explainCode = explainCode
        self.generateDocs = generateDocs
        self.fixCode = fixCode
    }
}
