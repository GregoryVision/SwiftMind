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
    case modelMissing(String)
    case timeout(Double)
    
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
        case .modelMissing(let model):
            return "Model '\(model)' is not available in Ollama."
        case .timeout(let seconds):
            return "Request to Ollama timed out after \(seconds)s."
            
        }
    }
    public var failureReason: String? {
        switch self {
        case .modelMissing:
            return "The requested model is not present locally."
        case .timeout:
            return "The model did not return a response within the configured timeout."
        case .ollamaNotInstalled:
            return "Ollama binary was not found in the current environment."
        default:
            return nil
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .modelMissing(let model):
            return "Run: `ollama pull \(model)` or choose another installed model."
        case .timeout:
            return "Increase the timeout, ensure the model is loaded, or try again later."
        case .ollamaNotInstalled:
            return "Install Ollama from https://ollama.com and ensure it is in your PATH."
        default:
            return nil
        }
    }
}
