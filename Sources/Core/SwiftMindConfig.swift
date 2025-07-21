//
//  File.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 11.06.2025.
//

import Foundation
import os.log

public struct SwiftMindConfig: Codable, Sendable {
    public private(set) var testsDirectory: String
    public private(set) var defaultModel: String
    public private(set) var tokenLimit: Int
    public private(set) var maxRetries: Int
    public private(set) var timeoutSeconds: Double
    public private(set) var documentationDeclarations: [String]
    public var promptMaxLength: Int {
        switch defaultModel.lowercased() {
        case "codellama":
            return 50_000 // Approx. 12.5k tokens
        case "mistral":
            return 32_000 // Approx. 8k tokens
        case "llama3":
            return 128_000 // Approx. 32k tokens
        default:
            return 50_000 // Safe default
        }
    }
    
    private static let logger = Logger(subsystem: "SwiftMind", category: "Config")
    
    public static let `default` = SwiftMindConfig(
        testsDirectory: "",
        defaultModel: "codellama",
        tokenLimit: 16000,
        maxRetries: 3,
        timeoutSeconds: 150.0,
        documentationDeclarations: ["func", "class", "struct", "init", "enum", "protocol"]
    )
    
    public static func load() -> SwiftMindConfig {
        let currentDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        
        if let configURL = findConfigPlist(startingFrom: currentDir) {
            logger.info("Found config at: \(configURL.path)")
            
            do {
                let data = try Data(contentsOf: configURL)
                let config = try PropertyListDecoder().decode(SwiftMindConfig.self, from: data)
                logger.info("Successfully loaded configuration")
                return config
            } catch {
                logger.warning("Failed to load config: \(error.localizedDescription). Using defaults.")
            }
        } else {
            logger.info("No config file found, using defaults")
        }
        
        return .default
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
}
