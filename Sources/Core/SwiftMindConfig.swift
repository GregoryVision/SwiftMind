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

    public static func load(startingFrom startDir: URL? = nil) -> SwiftMindConfig {
        let start = startDir ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        if let url = findConfigPlist(startingFrom: start) {
            Self.logger.info("Found config at: \(url.path)")
            do {
                return try SwiftMindConfig(fromFile: url)
            } catch {
                Self.logger.warning("Failed to load config: \(error.localizedDescription). Using defaults.")
            }
        } else {
            Self.logger.info("No config file found, using defaults")
        }
        return SwiftMindConfig() // явный вызов базового init с дефолтами
    }
    
    public static func findConfigPlist(startingFrom directory: URL) -> URL? {
        var current = directory
        
        while current.path != "/" {
            let candidate = current.appendingPathComponent("swiftmind.plist")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            current.deleteLastPathComponent()
        }
        
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
