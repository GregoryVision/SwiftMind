//
//  StringExtensionsTests.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 02.09.2025.
//

import XCTest
@testable import Core

final class StringExtensionsTests: XCTestCase {
    
    let messyToCanonical: [String: String] = [
        """
        func  foo (
           x : Int
           )   ->   Int
        """:
        "func foo(x:Int )->Int",

        "func foo(x :  Int)-> Int":
        "func foo(x:Int)->Int",

        "func foo (x:Int ) -> Int":
        "func foo(x:Int )->Int",
        
        "func bar<T : Equatable>(value : T)  async   throws   ->  Bool":
        "func bar<T:Equatable>(value:T) async throws->Bool",

        "func baz<T    >( _ x:Int)->   [String : Int ]":
        "func baz<T >(_ x:Int)->[String:Int ]",

        "  func qux()where   T : Codable  ":
        "func qux()where T:Codable",

        "func sum(_ a:Int, b : Int)-> Int ":
        "func sum(_ a:Int, b:Int)->Int",

        "func make(_ x :[String: Int ] , y:[ Int :String])->   Void":
        "func make(_ x:[String:Int ], y:[ Int:String])->Void",

        "func ping()   async   ->   Void":
        "func ping() async->Void",

        "func op()    throws   ->  Bool":
        "func op() throws->Bool"
    ]
    
    func testCanonicalizedSignatureKey() {
        
        for (input, expected) in messyToCanonical {
            XCTAssertEqual(
                input.canonicalizedSignatureKey(),
                expected,
                "Failed for input:\n\(input)"
            )
        }
    }
    func testSsProbablySignatureLike() {
        for fn in messyToCanonical.values {
            XCTAssertTrue(fn.isProbablySignatureLike)
        }
    }
}
