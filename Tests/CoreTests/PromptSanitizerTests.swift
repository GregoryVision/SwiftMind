//
//  PromptSanitizerTests.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 02.09.2025.
//

import XCTest
@testable import Core

final class PromptSanitizerTests: XCTestCase {
    
    func testPromptSanitizer() throws {
        let input = "input"
        let maxLength = 2
        let res = try PromptSanitizer.sanitize(input, maxLength: maxLength)
        XCTAssertNotNil(res.1)
        XCTAssertEqual(res.0, "in")
    }
    
    func testPromptSanitizerUnused() throws {
        let input = "input"
        let maxLength = input.count
        let res = try PromptSanitizer.sanitize(input, maxLength: maxLength)
        XCTAssertNil(res.1)
        XCTAssertEqual(res.0, input)
    }
}
