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
    
    public static func sanitizePath(_ path: String) -> String {
        return URL(fileURLWithPath: path).standardized.path
    }
    
    public static func sanitizeFileName(_ fileName: String) -> String {
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
    public static func loadAdditionalContext(from inputs: [String],
                                      base: URL,
                                      options: ContextOptions) async throws -> String? {
        guard !inputs.isEmpty else { return nil }
        
        // 1) Разворачиваем вход (файлы/директории) в список файлов
        let files = try expandInputsToFiles(inputs, base: base, options: options)
        guard !files.isEmpty else { return nil }
        
        // 2) Читаем по порядку, соблюдая лимит байт
        var total = 0
        var parts: [String] = []
        
        for file in files {
            let data = try Data(contentsOf: file)
            if total + data.count > options.maxBytes { break }
            total += data.count
            
            // относительный путь для заголовка
            let rel = file.path.replacingOccurrences(of: base.standardized.path + "/", with: "")
            
            // безопасно декодируем в UTF-8
            let text = String(decoding: data, as: UTF8.self)
            
            parts.append(text)
        }
        
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: "\n\n")
    }
    // MARK: - Expander: файлы и директории → список файлов
    
    private static func expandInputsToFiles(
        _ inputs: [String],
        base: URL,
        options: ContextOptions
    ) throws -> [URL] {
        var result = Set<URL>()
        
        for raw in inputs {
            let url = URL(fileURLWithPath: raw, relativeTo: base).standardized
            
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) {
                if isDir.boolValue {
                    try walkDirectory(url, base: base, into: &result, options: options, depth: 0)
                } else {
                    if matches(url, include: options.includeGlobs, exclude: options.excludeGlobs) {
                        result.insert(url)
                    }
                }
            } else {
                logger.warning("Context path not found: \(url.path)")
            }
        }
        
        return Array(result).sorted { $0.path.localizedCaseInsensitiveCompare($1.path) == .orderedAscending }
    }
    
    private static func walkDirectory(
        _ dir: URL,
        base: URL,
        into out: inout Set<URL>,
        options: ContextOptions,
        depth: Int
    ) throws {
        if let maxDepth = options.maxDepth, depth > maxDepth { return }
        
        let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey, .nameKey]
        let contents = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])
        
        for entry in contents {
            let values = try entry.resourceValues(forKeys: Set(keys))
            
            if values.isSymbolicLink == true && !options.followSymlinks { continue }
            
            // быстрый exclude по пути
            let rel = entry.path.replacingOccurrences(of: base.standardized.path + "/", with: "")
            if matchesPath(rel, globs: options.excludeGlobs) { continue }
            
            if values.isDirectory == true {
                try walkDirectory(entry, base: base, into: &out, options: options, depth: depth + 1)
            } else {
                if matches(entry, include: options.includeGlobs, exclude: options.excludeGlobs) {
                    out.insert(entry)
                }
            }
        }
    }
    
    // MARK: - Glob matching
    
    private static func matches(_ url: URL, include: [String], exclude: [String]) -> Bool {
        let fullPath = url.path
        // exclude — по полному пути
        if matchesPath(fullPath, globs: exclude) { return false }

        // include — по имени файла
        if include.isEmpty { return true }
        let name = url.lastPathComponent
        return matchesName(name, globs: include)
    }

    private static func matchesName(_ name: String, globs: [String]) -> Bool {
        for glob in globs {
            if name.range(of: globToRegex(glob), options: .regularExpression) != nil {
                return true
            }
        }
        return false
    }

    // exclude по полному пути
    private static func matchesPath(_ path: String, globs: [String]) -> Bool {
        for glob in globs {
            if path.range(of: globToRegex(glob), options: .regularExpression) != nil {
                return true
            }
        }
        return false
    }

    private static func globToRegex(_ glob: String) -> String {
        // Простейший glob → regex: ** -> .*, * -> [^/]* (не матчит слэши в include по имени)
        var pattern = NSRegularExpression.escapedPattern(for: glob)
        pattern = pattern.replacingOccurrences(of: "\\*\\*", with: ".*")
        pattern = pattern.replacingOccurrences(of: "\\*", with: "[^/]*")
        return "^\(pattern)$"
    }
}
// MARK: - FileHelper+resolveTestsDirectory

public extension FileHelper {
    
    /// Determines the folder where generated tests should be placed.
    /// Priority:
    ///   1. `cliOverride`   – value of `--output`, if provided.
    ///   2. `cfg.testsDirectory` from swiftmind.plist.
    ///   3. Fallback: ./GeneratedTests next to the analysed file.
    ///
    /// - Parameters:
    ///   - cliOverride:      Path passed via `--output` (may be relative or absolute; nil if flag not used).
    ///   - cfg:              Loaded configuration object.
    ///   - fileAbsolutePath: Absolute path to the source file being analysed.
    ///
    /// - Returns: URL of an existing (or newly-created) directory for tests.
    static func resolveTestsDirectory(
        cliOverride: String?,
        cfg: SwiftMindConfigProtocol,
        fileAbsolutePath: String
    ) throws -> URL {
        
        // Folder in which the analysed file lives
        let baseDir = URL(fileURLWithPath: fileAbsolutePath)
            .deletingLastPathComponent()
        
        // 1️⃣ CLI override — highest priority
        if let manual = cliOverride, !manual.isEmpty {
            let abs = URL(fileURLWithPath: manual, relativeTo: baseDir).standardized
            logger.info("Tests file path relolved to manual: \(abs.path())")
            return try ensureTestsDirectory(atAbsolutePath: abs.path())
        }
        
        // 2️⃣ Path from swiftmind.plist (may also be relative)
        if !cfg.testsDirectory.isEmpty {
            let cfgURL = URL(fileURLWithPath: cfg.testsDirectory, relativeTo: baseDir).standardized
            logger.info("Tests file path relolved to swiftmind.plist: \(cfgURL.path())")
            return try ensureTestsDirectory(atAbsolutePath: cfgURL.path())
        }
        
        // 3️⃣ Fallback — GeneratedTests alongside the source file
        let fallback = baseDir.appendingPathComponent("GeneratedTests", isDirectory: true)
        logger.info("Tests are generated alongside the source file: \(fallback.path())")
        return try ensureTestsDirectory(atAbsolutePath: fallback.path())
    }
}
