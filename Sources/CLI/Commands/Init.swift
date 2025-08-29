//
//  Init.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 27.08.2025.
//

import ArgumentParser
import Foundation
import os.log
import Core

/// Initializes a `swiftmind.plist` in the current project directory.
///
/// By default writes a minimal template bundled with the package. You can override the
/// destination directory via `--path` and the template via `--template`. Use `--force` to
/// overwrite an existing file.
struct Init: AsyncParsableCommand {
    /// Command configuration shown in `--help`.
    static let configuration = CommandConfiguration(
        abstract: "Create a swiftmind.plist in the current project"
    )

    /// Subsystem logger for the `Init` command.
    private static let logger = Logger(subsystem: "SwiftMind", category: "Init")

    /// Target directory to place `swiftmind.plist` (defaults to current directory).
    @Option(name: .shortAndLong, help: "Target directory to place swiftmind.plist (defaults to current directory)")
    var path: String?

    /// Path to a custom template `.plist` (overrides the bundled template).
    @Option(name: .long, help: "Path to a custom template .plist (overrides bundled template)")
    var template: String?

    /// Overwrite existing `swiftmind.plist` if present.
    @Flag(name: .shortAndLong, help: "Overwrite existing swiftmind.plist if present")
    var force: Bool = false

    /// Entry point for the `init` subcommand.
    func run() async throws {
        do {
            let fm = FileManager.default

            // 1) Resolve destination directory
            let dirURL: URL = {
                if let p = path { return URL(fileURLWithPath: p).standardizedFileURL }
                return URL(fileURLWithPath: fm.currentDirectoryPath).standardizedFileURL
            }()
            try fm.createDirectory(at: dirURL, withIntermediateDirectories: true)

            let target = dirURL.appendingPathComponent("swiftmind.plist")

            // 2) Check for existing file
            if fm.fileExists(atPath: target.path) && !force {
                print("⚠️  swiftmind.plist already exists at \(target.path). Use --force to overwrite.")
                return
            }

            // 3) Resolve template: explicit --template, bundled resource, or minimal default
            let contentsData: Data
            if let custom = template {
                contentsData = try Data(contentsOf: URL(fileURLWithPath: custom))
            } else if let bundled = Self.bundledTemplateURL() {
                contentsData = try Data(contentsOf: bundled)
            } else {
                contentsData = Data(Self.defaultTemplate.utf8)
            }

            // 4) Write file
            try contentsData.write(to: target, options: .atomic)

            print("✅ Created \(target.path)")
        } catch {
            try SwiftMindError.handle(error)
        }
    }

    /// Returns URL to the bundled template `swiftmind.plist` (when built as Swift Package).
    private static func bundledTemplateURL() -> URL? {
        #if SWIFT_PACKAGE
        return Bundle.module.url(forResource: "swiftmind", withExtension: "plist", subdirectory: "Templates")
        #else
        return nil
        #endif
    }

    /// Minimal fallback template used when a bundled file is not available.
    private static let defaultTemplate = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>defaultModel</key>
      <string>qwen2.5-coder:14b</string>
      <key>promptMaxLength</key>
      <integer>50000</integer>
      <key>testsDirectory</key>
      <string>GeneratedTests</string>
      <key>documentationDeclarations</key>
      <array>
        <string>FunctionDeclSyntax</string>
      </array>
    </dict>
    </plist>
    """
}
