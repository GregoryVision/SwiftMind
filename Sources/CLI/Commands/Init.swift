//
//  Init.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 27.08.2025.
//

import ArgumentParser
import Foundation
import os.log

struct Init: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Create a swiftmind.plist in the current project"
    )
    private static let logger = Logger(subsystem: "SwiftMind", category: "Init")

    @Option(name: .shortAndLong, help: "Target directory to place swiftmind.plist (defaults to current directory)")
    var path: String?

    @Option(name: .long, help: "Path to a custom template .plist (overrides bundled template)")
    var template: String?

    @Flag(name: .shortAndLong, help: "Overwrite existing swiftmind.plist if present")
    var force: Bool = false

    func run() async throws {
        let fm = FileManager.default

        // 1) Куда писать
        let dirURL: URL = {
            if let p = path { return URL(fileURLWithPath: p).standardizedFileURL }
            return URL(fileURLWithPath: fm.currentDirectoryPath).standardizedFileURL
        }()
        try fm.createDirectory(at: dirURL, withIntermediateDirectories: true)

        let target = dirURL.appendingPathComponent("swiftmind.plist")

        // 2) Проверка существования
        if fm.fileExists(atPath: target.path) && !force {
            print("⚠️  swiftmind.plist already exists at \(target.path). Use --force to overwrite.")
            return
        }

        // 3) Достаём шаблон: из --template или из ресурсов пакета, иначе дефолтный
        let contentsData: Data
        if let custom = template {
            contentsData = try Data(contentsOf: URL(fileURLWithPath: custom))
        } else if let bundled = Self.bundledTemplateURL() {
            contentsData = try Data(contentsOf: bundled)
        } else {
            contentsData = Data(Self.defaultTemplate.utf8)
        }

        // 4) Пишем файл
        try contentsData.write(to: target, options: .atomic)

        print("✅ Created \(target.path)")
    }

    private static func bundledTemplateURL() -> URL? {
        #if SWIFT_PACKAGE
        return Bundle.module.url(forResource: "swiftmind", withExtension: "plist", subdirectory: "Templates")
        #else
        return nil
        #endif
    }

    // Фолбэк-шаблон (минимальный)
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
