//
//  FileHelper+resolveTestsDirectory.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 29.08.2025.
//

import Foundation
import os.log

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
