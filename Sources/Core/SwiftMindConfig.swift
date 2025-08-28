//
//  File.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 11.06.2025.
//

import Foundation
import os.log

public protocol SwiftMindConfigProtocol: Sendable {
    var testsDirectory: String { get }
    var defaultModel: String { get }
    var tokenLimit: Int { get }
    var maxRetries: Int { get }
    var timeoutSeconds: Double { get }
    var documentationDeclarations: [String] { get }
    var promptMaxLength: Int { get }
    var maxFileSizeMB: Int { get }
    var maxFileSize: Int { get }
    func validate() throws
}

public struct SwiftMindConfig: SwiftMindConfigProtocol, Codable, Sendable {
    public private(set) var testsDirectory: String
    public private(set) var defaultModel: String
    public private(set) var tokenLimit: Int
    public private(set) var maxRetries: Int
    public private(set) var timeoutSeconds: Double
    public private(set) var documentationDeclarations: [String]
    
    public var promptMaxLength: Int {
        switch defaultModel.lowercased() {
        default:
//            return 550_000 // for deepseek-coder-v2:16b
            return 120000// for qwen2.5-coder:14b and codestral:22b
        }
    }
    
    public var maxFileSizeMB: Int { 1 } // Default 1 MB
    public var maxFileSize: Int { maxFileSizeMB * 1024 * 1024 }
    
    private static let logger = Logger(subsystem: "SwiftMind", category: "Config")

    public init(
        testsDirectory: String = "",
        defaultModel: String = "qwen2.5-coder:14b",
        tokenLimit: Int = 32000,
        maxRetries: Int = 3,
        timeoutSeconds: Double = 240.0,
        documentationDeclarations: [String] = ["func", "class", "struct", "init", "enum", "protocol"]
    ) {
        self.testsDirectory = testsDirectory
        self.tokenLimit = tokenLimit
        self.maxRetries = maxRetries
        self.timeoutSeconds = timeoutSeconds
        self.documentationDeclarations = documentationDeclarations
//        let byteCount = ProcessInfo.processInfo.physicalMemory
//        let ram = Int(byteCount) / 1_073_741_824
//        self.defaultModel = ram >= 24 ? "codellama:13b-instruct" : "codellama:7b-instruct"
        self.defaultModel = defaultModel
    }

    /// Loads config from a swiftmind.plist file at the given path.
    public init(fromFile fileURL: URL) throws {
        let data = try Data(contentsOf: fileURL)
        self = try PropertyListDecoder().decode(SwiftMindConfig.self, from: data)
    }
    
    /// Ищет `swiftmind.plist` рекурсивно ВНИЗ от `startDir`.
    /// Возвращает первый найденный (детерминированно — в порядке обхода файловой системы).
    public static func findConfigPlistDownward(
        startingFrom startDir: URL,
        fileName: String = "swiftmind.plist",
        ignoreDirs: Set<String> = [".git", ".build", "build", "DerivedData", "node_modules"],
        maxDepth: Int? = nil,
        followSymlinks: Bool = false
    ) -> URL? {
        
        let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey, .nameKey]
        
        guard let enumerator = FileManager.default.enumerator(
            at: startDir,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles], // скрытые пропускаем
            errorHandler: { url, err in
                // Можно залогировать, но не падать
                // print("Enumerator error at \(url.path): \(err)")
                return true
            }
        ) else { return nil }
        
        let baseComponents = startDir.standardized.pathComponents.count
        
        for case let url as URL in enumerator {
            // Глубина (относительно стартовой)
            if let maxDepth = maxDepth {
                let depth = url.standardized.pathComponents.count - baseComponents
                if depth > maxDepth {
                    enumerator.skipDescendants()
                    continue
                }
            }
            
            // Узнаём тип, имя, симлинк
            guard let rv = try? url.resourceValues(forKeys: Set(keys)) else { continue }
            let name = rv.name ?? url.lastPathComponent
            
            // Игнорируем нежелательные директории
            if rv.isDirectory == true {
                if ignoreDirs.contains(name) {
                    enumerator.skipDescendants()
                    continue
                }
                if rv.isSymbolicLink == true && !followSymlinks {
                    enumerator.skipDescendants()
                    continue
                }
                continue
            }
            
            if name == fileName {
                return url
            }
        }
        return nil
    }
    
    /// Пытается сначала найти вниз, а если нет — поднимается вверх (как у тебя было).
    public static func load(startingFrom startDir: URL? = nil) -> SwiftMindConfig {
        let start = (startDir ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)).standardized
        
        // 1) Сначала ищем вниз (если ты в корне проекта, это сработает)
        if let url = findConfigPlistDownward(startingFrom: start) {
            print("Found config (downward) at: \(url.path)")
            do {
                return try SwiftMindConfig(fromFile: url)
            }
            catch {
                print("Failed to load config: \(error.localizedDescription). Using defaults.")
            }
        }
        
        // 2) Фоллбэк — как раньше: вверх по дереву
        if let url = findConfigPlistUpward(startingFrom: start) {
            print("Found config (upward) at: \(url.path)")
            do {
                return try SwiftMindConfig(fromFile: url)
            }
            catch {
                print("Failed to load config: \(error.localizedDescription). Using defaults.")
            }
        }
        
        print("No config file found, using defaults")
        return SwiftMindConfig()
    }
    
    /// Твой прежний «поиск вверх».
    public static func findConfigPlistUpward(startingFrom directory: URL, fileName: String = "swiftmind.plist") -> URL? {
        var current = directory.standardized
        let fm = FileManager.default
        repeat {
            let candidate = current.appendingPathComponent(fileName)
            if fm.fileExists(atPath: candidate.path) {
                return candidate
            }
            current.deleteLastPathComponent()
        } while current.path != "/"
        return nil
    }
    
    public func validate() throws {
        guard tokenLimit > 0 else {
            throw SwiftMindError.configurationError("Token limit must be positive")
        }
        
        guard maxRetries > 0 else {
            throw SwiftMindError.configurationError("Max retries must be positive")
        }
        
        guard timeoutSeconds > 0 else {
            throw SwiftMindError.configurationError("Timeout must be positive")
        }
    }
    private func systemRAMInGB() -> Int {
        let byteCount = ProcessInfo.processInfo.physicalMemory
        return Int(byteCount) / 1_073_741_824 // 1024^3
    }
}
