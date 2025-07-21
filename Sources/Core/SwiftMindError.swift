//
//  SwiftMindError.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 16.06.2025.
//

import Foundation

// MARK: - Errors
public enum SwiftMindError: LocalizedError {
    case fileNotFound(String)
    case invalidFilePath(String)
    case ollamaNotInstalled
    case ollamaExecutionFailed(Int32, String)
    case fileTooLarge(String, Int)
    case unsupportedFileType(String)
    case configurationError(String)
    case promptTooLong(Int, Int)
    
    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .invalidFilePath(let path):
            return "Invalid file path: \(path)"
        case .ollamaNotInstalled:
            return "Ollama is not installed or not available in PATH. Please install Ollama first."
        case .ollamaExecutionFailed(let code, let error):
            return "Ollama execution failed (exit code \(code)): \(error)"
        case .fileTooLarge(let path, let size):
            return "File too large (\(size) bytes): \(path). Maximum allowed size is 1MB."
        case .unsupportedFileType(let path):
            return "Unsupported file type: \(path). Only .swift files are supported."
        case .configurationError(let message):
            return "Configuration error: \(message)"
        case .promptTooLong(let promptCount, let maxLength):
            return "Prompt was truncated from \(promptCount) to \(maxLength) characters"
        }
    }
}
