//
//  AIUseCases.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 06.06.2025.
//

import Foundation
import os.log

public protocol AIUseCasesProtocol {
    var generateTests: GenerateTestsUseCase { get }
    var reviewCode: ReviewCodeUseCase { get }
    var explainCode: ExplainCodeUseCase { get }
    var generateDocs: GenerateDocumentationUseCase { get }
}

public final class AIUseCases: AIUseCasesProtocol {
    public let generateTests: GenerateTestsUseCase
    public let reviewCode: ReviewCodeUseCase
    public let explainCode: ExplainCodeUseCase
    public let generateDocs: GenerateDocumentationUseCase

    public init(
        generateTests: GenerateTestsUseCase,
        reviewCode: ReviewCodeUseCase,
        explainCode: ExplainCodeUseCase,
        generateDocs: GenerateDocumentationUseCase
    ) {
        self.generateTests = generateTests
        self.reviewCode = reviewCode
        self.explainCode = explainCode
        self.generateDocs = generateDocs
    }
}
