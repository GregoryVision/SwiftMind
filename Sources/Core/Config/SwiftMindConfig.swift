//
//  File.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 11.06.2025.
//

import Foundation
import os.log

/// Public interface for SwiftMind configuration.
public protocol SwiftMindConfigProtocol: Sendable {
    /// Directory where generated tests should be placed.
    var testsDirectory: String { get }
    /// Default LLM model identifier (as understood by Ollama).
    var defaultModel: String { get }
    /// Token limit for the selected model.
    var tokenLimit: Int { get }
    /// Max number of retry attempts on Ollama calls.
    var maxRetries: Int { get }
    /// Timeout for a single Ollama call, in seconds.
    var timeoutSeconds: Double { get }
    /// Declaration kinds that should be documented (e.g., `func`, `class`, `struct`).
    var documentationDeclarations: [String] { get }
    /// Prompt length limit used in sanitization (depends on model).
    var promptMaxLength: Int { get }
    /// Maximum file size in MB (user-facing).
    var maxFileSizeMB: Int { get }
    /// Maximum file size in bytes (derived).
    var maxFileSize: Int { get }

    /// Validates internal invariants (throws if misconfigured).
    func validate() throws
}

/// Default config implementation, loaded from `swiftmind.plist` or defaults.
public struct SwiftMindConfig: SwiftMindConfigProtocol, Codable, Sendable {
    public private(set) var testsDirectory: String
    public private(set) var defaultModel: String
    public private(set) var tokenLimit: Int
    public private(set) var maxRetries: Int
    public private(set) var timeoutSeconds: Double
    public private(set) var documentationDeclarations: [String]
    
    /// Derived prompt length limit depending on model.
    public var promptMaxLength: Int {
        switch defaultModel.lowercased() {
        default:
            return 120_000 // tuned for qwen2.5-coder:14b
        }
    }
    
    /// Maximum file size in MB (default: 1 MB).
    public var maxFileSizeMB: Int { 1 }
    /// Maximum file size in bytes (derived).
    public var maxFileSize: Int { maxFileSizeMB * 1024 * 1024 }
    
    private static let logger = Logger(subsystem: "SwiftMind", category: "Config")

    /// Creates a config object from values or defaults.
    public init(
        testsDirectory: String = "",
        defaultModel: String = "qwen2.5-coder:14b",
        tokenLimit: Int = 32_000,
        maxRetries: Int = 3,
        timeoutSeconds: Double = 240.0,
        documentationDeclarations: [String] = ["func", "class", "struct", "init", "enum", "protocol"]
    ) {
        self.testsDirectory = testsDirectory
        self.tokenLimit = tokenLimit
        self.maxRetries = maxRetries
        self.timeoutSeconds = timeoutSeconds
        self.documentationDeclarations = documentationDeclarations
        self.defaultModel = defaultModel
    }

    /// Loads config from a `.plist` file.
    public init(fromFile fileURL: URL) throws {
        let data = try Data(contentsOf: fileURL)
        self = try PropertyListDecoder().decode(SwiftMindConfig.self, from: data)
    }
    
    /// Loads config: tries downward search, then upward search, else falls back to defaults.
    public static func load(startingFrom startDir: URL? = nil) -> SwiftMindConfig {
        if let url = ConfigLocator.locateURL(startingFrom: startDir) {
            print("Found config at: \(url.path)")
            do {
                return try SwiftMindConfig(fromFile: url)
            } catch {
                print("Failed to load config: \(error.localizedDescription). Using defaults.")
            }
        } else {
            print("No config file found, using defaults")
        }
        return SwiftMindConfig()
    }
    
    /// Validates internal invariants of the configuration.
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

    /// Returns system physical RAM in GB (approximate).
    private func systemRAMInGB() -> Int {
        let byteCount = ProcessInfo.processInfo.physicalMemory
        return Int(byteCount) / 1_073_741_824 // 1024^3
    }
}
