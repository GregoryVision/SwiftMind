//
//  CodeProcessingService.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 19.08.2025.
//

import Foundation

public struct CodeProcessingService {
    public static func prepareCode(from path: String, promptMaxLength: Int) throws -> (URL, String, String)  {
        let resolvedFileURL = FileHelper.resolve(filePath: path)
        try FileHelper.validateFile(at: resolvedFileURL)
        let (fileName, code) = try FileHelper.readCode(atAbsolutePath: resolvedFileURL.path)
        let satitizedCode = try PromptSanitizer.sanitize(code, maxLength: promptMaxLength)
        return (resolvedFileURL, fileName, satitizedCode)
    }
}
