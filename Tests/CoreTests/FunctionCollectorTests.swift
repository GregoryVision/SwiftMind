//
//  FunctionCollectorTests.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 02.09.2025.
//

import XCTest
@testable import Core

final class FunctionCollectorTests: XCTestCase {
    
    let source = """
    import Foundation

    struct Service<T> {
        let baseURL: URL

        init(baseURL: URL) {
            self.baseURL = baseURL
        }

        func foo(x: Int) -> Int { x }

        func foo(_ x: Int, y: String = "def") -> String { "\\(x)-\\(y)" }

        func compute(a: Int, b: Int?) throws -> Int {
            guard let b else { throw NSError(domain: "E", code: 1) }
            return a + b
        }

        func fetch(path: String) async throws -> Data {
            let url = baseURL.appendingPathComponent(path)
            // имитация I/O
            return Data(url.absoluteString.utf8)
        }

        func map<U>(_ value: T, _ transform: (T) -> U) -> U {
            transform(value)
        }
    }

    extension Service where T: Equatable {
        func equals(_ lhs: T, _ rhs: T) -> Bool { lhs == rhs }
    }
    """
    
    func testCollectsFunctionsCount() {
        let collector = FunctionCollector.collect(from: source)
        XCTAssertEqual(collector.functions.count, 6, "Should collect 6 function declarations")
    }
    
    func testCollectsFunctionsSigs() {
        let collector = FunctionCollector.collect(from: source)
        let sigs = Set(collector.functions.map { $0.signatureString })
        XCTAssertTrue(sigs.contains("func foo(x: Int) -> Int"))
        XCTAssertTrue(sigs.contains("func foo(_ x: Int, y: String) -> String"))
        XCTAssertTrue(sigs.contains("func compute(a: Int, b: Int?) throws -> Int"))
        XCTAssertTrue(sigs.contains("func fetch(path: String) async throws -> Data"))
        XCTAssertTrue(sigs.contains("func map<U>(_ value: T, _ transform: (T) -> U) -> U"))
        XCTAssertTrue(sigs.contains("func equals(_ lhs: T, _ rhs: T) -> Bool"))
    }
    
    func testFunctionDeclsFilterByName() {
        let collector = FunctionCollector.collect(from: source)
        let declsByName = collector.functionDecls(target: "foo")
        XCTAssertEqual(declsByName.count, 2)
    }
    
    func testFunctionDeclsFilterBySign() {
        let collector = FunctionCollector.collect(from: source)
        let sign = "func foo(x: Int) -> Int"
        let declsBySigns = collector.functionDecls(target: sign)
        XCTAssertFalse(declsBySigns.isEmpty)
        XCTAssertEqual(declsBySigns.first?.signatureString, sign)
    }
}
