//
//  CodeProcessingService.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 19.08.2025.
//

import Foundation

/// Lightweight utilities for preparing Swift source code for analysis and AI processing.
public struct CodeProcessingService {
    
    /// Result of initial code preparation.
    public struct CodeProcessingResult {
        /// Absolute URL to the resolved source file on disk.
        public let resolvedFileURL: URL
        /// File name without extension.
        public let fileName: String
        /// Sanitized Swift source code (as read from disk).
        public let sanitizedCode: String
    }
    
    /// Resolves a path, validates the target file, and loads its contents.
    ///
    /// - Parameter path: A relative or absolute path to a `.swift` file.
    /// - Returns: `CodeProcessingResult` with resolved file URL, file name, and source text.
    /// - Throws: `SwiftMindError` or `ValidationError` when resolution/validation fails.
    public static func prepareCode(from path: String) throws -> CodeProcessingResult  {
        let resolvedFileURL = FileHelper.resolve(filePath: path)
        try FileHelper.validateFile(at: resolvedFileURL)
        let (fileName, code) = try FileHelper.readCode(atAbsolutePath: resolvedFileURL.path)
        return CodeProcessingResult(
            resolvedFileURL: resolvedFileURL,
            fileName: fileName,
            sanitizedCode: code
        )
    }
    
    /// Tries to extract a module/project label from the header comment.
    ///
    /// Heuristic: scans the **first 5 lines** and returns the first non-empty line comment
    /// that:
    /// - starts with `//` (ignoring leading whitespace),
    /// - does **not** contain `.swift`,
    /// - and does **not** contain the word `created` (case-insensitive).
    ///
    /// Also strips a potential UTF-8 BOM (`\u{FEFF}`) if present.
    ///
    /// - Parameter code: Full Swift source text.
    /// - Returns: Module name or `nil` if nothing matches.
    public static func extractModuleName(from code: String) -> String? {
        let maxHeaderLines = 5
        let lines = code.split(separator: "\n").prefix(maxHeaderLines) // read first N lines
        for line in lines {
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("//") {
                // Remove leading `//`, whitespace, and potential BOM.
                let content = line
                    .replacingOccurrences(of: "//", with: "")
                    .replacingOccurrences(of: "\u{FEFF}", with: "")
                    .trimmingCharacters(in: .whitespaces)
                
                if !content.isEmpty,
                   !content.contains(".swift"),
                   !content.lowercased().contains("created") {
                    return content
                }
            }
        }
        return nil
    }
}
