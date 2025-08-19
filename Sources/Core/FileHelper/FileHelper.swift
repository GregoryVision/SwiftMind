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
    
    private static let logger = Logger(subsystem: "SwiftMind", category: "FileHelper")
    
    private static var maxFileSize: Int {
        let config = SwiftMindConfig()
        return config.maxFileSize + 1024
    }
    private static let supportedExtensions: Set<String> = ["swift"]
    
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
        
        let fileName = fileURL.lastPathComponent.replacingOccurrences(of: ".swift", with: "")
        let code = try String(contentsOf: fileURL)
        
        return (fileName, code)
        
    }
    
    public static func ensureTestsDirectory(atAbsolutePath absolutePath: String) throws -> URL {
        let testDirectory = URL(fileURLWithPath: absolutePath, isDirectory: true)
        
        if !FileManager.default.fileExists(atPath: testDirectory.path) {
            try FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)
        }
        
        return testDirectory
    }
    
    public static func save(text: String, to directory: URL, fileName: String) throws -> URL {
        // Validate filename
        let sanitizedFileName = sanitizeFileName(fileName)
        let fileURL = directory.appendingPathComponent(sanitizedFileName)
        
        logger.info("Saving file: \(fileURL.path)")
        try text.write(to: fileURL, atomically: true, encoding: .utf8)
        
        return fileURL
    }
    
    public static func resolve(filePath: String) -> URL {
        let baseURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let resolvedFileURL = URL(fileURLWithPath: filePath, relativeTo: baseURL).standardized
        return resolvedFileURL.absoluteURL
    }
    
    private static func sanitizePath(_ path: String) -> String {
        return URL(fileURLWithPath: path).standardized.path
    }
    
    private static func sanitizeFileName(_ fileName: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        let cleaned = fileName
            .components(separatedBy: invalidCharacters)
            .joined(separator: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleaned
    }
    
    public static func validateFile(at url: URL) throws {
        let path = url.path
        guard FileManager.default.fileExists(atPath: path) else {
            throw ValidationError("File not found: \(path)")
        }

        guard supportedExtensions.contains(url.pathExtension) else {
            throw ValidationError("Only Swift files (.swift) are supported")
        }

        guard FileManager.default.isReadableFile(atPath: path) else {
            throw ValidationError("File is not readable: \(path)")
        }
    }
    
    /// Читает дополнительные файлы-контексты.
    /// - Parameters:
    ///   - paths:     Список путей (можно относительных и абсолютных)
    ///   - base:      Базовая директория, от которой «расправляем» относительные пути.
    /// - Returns:     Конкатенированное содержимое файлов (или пустая строка)
    public static func loadAdditionalContext(from paths: [String], base: URL) async throws -> String? {
        guard !paths.isEmpty else { return nil }
        var result = ""
        
        for raw in paths {
            // 1. Строим абсолютный URL независимо от формата ввода
            let fileURL = URL(fileURLWithPath: raw, relativeTo: base).standardized
            
            // 2. Проверяем существование
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                print("⚠️ Context file not found: \(fileURL.path)")
                continue
            }
            
            // 3. Читаем и добавляем
            let fileContent = try String(contentsOf: fileURL)
            result += "\n\n" + fileContent
        }
        return result
    }
}
