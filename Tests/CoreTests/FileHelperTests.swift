//
//  FileHelperTests.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 02.09.2025.
//

import XCTest
import ArgumentParser
@testable import Core

final class FileHelperTests: XCTestCase {
    
    func testReadCode() throws {
        let code = "func foo(x: Int) -> Int"
        let fileName = "test.swift"
        let fileURL = FileManager.default.temporaryDirectory.appending(path: fileName)
        try code.write(to: fileURL, atomically: true, encoding: .utf8)
        print("File saved at:", fileURL.path)
        
        let (resFileName, resCode) = try FileHelper.readCode(atAbsolutePath: fileURL.absoluteString)
        
        XCTAssertFalse(resFileName.isEmpty)
        XCTAssertEqual(code, resCode)
    }
    
    func testEnsureTestsDirectory() throws {
        let uniqueDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let resUrl = try FileHelper.ensureTestsDirectory(atAbsolutePath: uniqueDir.path())
        XCTAssertEqual(uniqueDir.standardizedFileURL, resUrl.standardizedFileURL)
    }
    
    func testSanitizeFileName() throws {
        let validNames = [
            "MyProject",
            "Sources",
            "docs_v1.2",
            "images-backup",
            "тестовая_папка",
            "データ",
            "my_folder_123"
        ]
        
        for name in validNames {
            let sanitized = FileHelper.sanitizeFileName(name)
            XCTAssertEqual(name, sanitized)
        }
        
        let invalidToValidNames: [String: String] = [
            "my/project": "my_project",
            "my\\project": "my_project",
            "report?.txt": "report_.txt",
            "budget%2024": "budget_2024",
            "data*backup": "data_backup",
            "notes|ideas": "notes_ideas",
            "quote\"test": "quote_test",
            "a<b>c": "a_b_c",
            "config:prod": "config_prod",
            "   spaced name  ": "spaced name"
        ]
        for (invalidName, validName) in invalidToValidNames {
            let sanitized = FileHelper.sanitizeFileName(invalidName)
            XCTAssertEqual(validName, sanitized)
        }
    }
    
    func testValidateFile() throws {
        let fileName = "test.swift"
        let fileURL = FileManager.default.temporaryDirectory.appending(path: fileName)
        FileManager.default.createFile(atPath: fileURL.path(), contents: nil)
        print("File saved at:", fileURL.path)
        try FileHelper.validateFile(at: fileURL)
    }
    
    func testValidateFile_failsForUnsupportedExtension() throws {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.txt")
        FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        
        XCTAssertThrowsError(try FileHelper.validateFile(at: fileURL)) { error in
            if let validationError = error as? ValidationError {
                XCTAssertTrue(validationError.message.contains("Only Swift files"))
            } else {
                XCTFail("Expected ValidationError, got \(type(of: error)): \(error)")
            }
        }
    }
}
