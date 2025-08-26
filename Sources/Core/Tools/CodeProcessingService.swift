//
//  CodeProcessingService.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 19.08.2025.
//

import Foundation

public struct CodeProcessingService {
    
    public struct CodeProcessingResult {
        public let resolvedFileURL: URL
        public let fileName: String
        public let sanitizedCode: String
    }
    
    public static func prepareCode(from path: String) throws -> CodeProcessingResult  {
        let resolvedFileURL = FileHelper.resolve(filePath: path)
        try FileHelper.validateFile(at: resolvedFileURL)
        let (fileName, code) = try FileHelper.readCode(atAbsolutePath: resolvedFileURL.path)
        return CodeProcessingResult(resolvedFileURL: resolvedFileURL,
                                    fileName: fileName,
                                    sanitizedCode: code)
    }
    
    public static func extractModuleName(from code: String) -> String? {
        let lines = code.split(separator: "\n").prefix(5) // читаем первые 5 строк
        for line in lines {
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("//") {
                let content = line.replacingOccurrences(of: "//", with: "").trimmingCharacters(in: .whitespaces)
                if !content.isEmpty && !content.contains(".swift") && !content.lowercased().contains("created") {
                    return content
                }
            }
        }
        return nil
    }
}
