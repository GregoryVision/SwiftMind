//
//  FileHelper.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 06.06.2025.
//
import Foundation
import os.log
import ArgumentParser

public struct FileHelper {
    
    static let logger = Logger(subsystem: "SwiftMind", category: "FileHelper")
    
    /// Maximum allowed source file size in bytes (config + small headroom).
    private static var maxFileSize: Int {
        let config = SwiftMindConfig()
        return config.maxFileSize + 1024
    }
    
    /// Supported source file extensions (lowercased).
    private static let supportedExtensions: Set<String> = ["swift"]
    
    /// Reads a Swift source file by absolute path with basic validation.
    /// - Parameter absolutePath: Absolute filesystem path to the `.swift` file.
    /// - Returns: Tuple `(fileName, code)` where `fileName` is without extension.
    public static func readCode(atAbsolutePath absolutePath: String) throws -> (fileName: String, code: String) {
        // Validate path
        guard !absolutePath.isEmpty else {
            throw SwiftMindError.invalidFilePath("Empty path")
        }
        
        // Sanitize path
        let sanitizedPath = sanitizePath(absolutePath)
        let fileURL = URL(fileURLWithPath: sanitizedPath)
        
        // Check file existence
        guard FileManager.default.fileExists(atPath: sanitizedPath) else {
            throw SwiftMindError.fileNotFound(sanitizedPath)
        }
        
        // Validate file type
        let fileExtension = fileURL.pathExtension.lowercased()
        guard supportedExtensions.contains(fileExtension) else {
            throw SwiftMindError.unsupportedFileType(sanitizedPath)
        }
        
        // Check file size
        let attributes = try FileManager.default.attributesOfItem(atPath: sanitizedPath)
        if let fileSize = attributes[.size] as? Int, fileSize > maxFileSize {
            throw SwiftMindError.fileTooLarge(sanitizedPath, fileSize)
        }
        
        logger.info("Reading file: \(sanitizedPath)")
        
        let fileName = fileURL.deletingPathExtension().lastPathComponent
        let code = try String(contentsOf: fileURL, encoding: .utf8)
        
        return (fileName, code)
    }
    
    /// Ensures that the given directory exists, creating it if needed.
    /// - Parameter absolutePath: Absolute path to the directory.
    /// - Returns: URL of the directory.
    public static func ensureTestsDirectory(atAbsolutePath absolutePath: String) throws -> URL {
        let testDirectory = URL(fileURLWithPath: absolutePath, isDirectory: true)
        
        if !FileManager.default.fileExists(atPath: testDirectory.path) {
            try FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)
        }
        
        return testDirectory
    }
    
    /// Saves text to a file inside the specified directory.
    /// - Parameters:
    ///   - text: File contents.
    ///   - directory: Directory URL.
    ///   - fileName: Desired file name (will be sanitized).
    /// - Returns: Full file URL.
    public static func save(text: String, to directory: URL, fileName: String) throws -> URL {
        // Validate filename
        let sanitizedFileName = sanitizeFileName(fileName)
        let fileURL = directory.appendingPathComponent(sanitizedFileName)
        
        logger.info("Saving file: \(fileURL.path)")
        try text.write(to: fileURL, atomically: true, encoding: .utf8)
        
        return fileURL
    }
    
    /// Resolves a (possibly relative) file path against the current working directory.
    public static func resolve(filePath: String) -> URL {
        let baseURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let resolvedFileURL = URL(fileURLWithPath: filePath, relativeTo: baseURL).standardized
        return resolvedFileURL.absoluteURL
    }
    
    /// Returns a standardized filesystem path for the given input.
    public static func sanitizePath(_ path: String) -> String {
        return URL(fileURLWithPath: path).standardized.path
    }
    
    /// Sanitizes a filename by removing characters invalid in common filesystems.
    public static func sanitizeFileName(_ fileName: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        let cleaned = fileName
            .components(separatedBy: invalidCharacters)
            .joined(separator: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleaned
    }
    
    /// Validates that a file exists, is readable, and has a supported extension.
    public static func validateFile(at url: URL) throws {
        let path = url.path
        guard FileManager.default.fileExists(atPath: path) else {
            throw ValidationError("File not found: \(path)")
        }
        
        guard supportedExtensions.contains(url.pathExtension.lowercased()) else {
            throw ValidationError("Only Swift files (.swift) are supported")
        }
        
        guard FileManager.default.isReadableFile(atPath: path) else {
            throw ValidationError("File is not readable: \(path)")
        }
    }
}
