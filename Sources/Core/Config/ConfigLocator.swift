//
//  ConfigLocator.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 29.08.2025.
//

import Foundation

/// Locates `swiftmind.plist` in the filesystem (downward/upward).
public struct ConfigLocator {
    /// Default config file name.
    public static let defaultFileName = "swiftmind.plist"

    /// Directories to skip during downward search.
    public static let defaultIgnoredDirs: Set<String> = [
        ".git", ".build", "build", "DerivedData", "node_modules"
    ]

    /// Searches **downward** from `startDir` for the first `swiftmind.plist`.
    /// - Parameters:
    ///   - startDir: Starting directory.
    ///   - fileName: Config file name (default `swiftmind.plist`).
    ///   - ignoreDirs: Directory names to skip completely.
    ///   - maxDepth: Optional max relative depth to traverse.
    ///   - followSymlinks: Whether to follow symlinks to directories.
    /// - Returns: URL of the first found config or `nil`.
    public static func findDownward(
        startingFrom startDir: URL,
        fileName: String = defaultFileName,
        ignoreDirs: Set<String> = defaultIgnoredDirs,
        maxDepth: Int? = nil,
        followSymlinks: Bool = false
    ) -> URL? {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey, .nameKey]

        guard let enumerator = FileManager.default.enumerator(
            at: startDir,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) else { return nil }

        let baseComponents = startDir.standardized.pathComponents.count

        for case let url as URL in enumerator {
            if let maxDepth = maxDepth {
                let depth = url.standardized.pathComponents.count - baseComponents
                if depth > maxDepth {
                    enumerator.skipDescendants()
                    continue
                }
            }

            guard let rv = try? url.resourceValues(forKeys: Set(keys)) else { continue }
            let name = rv.name ?? url.lastPathComponent

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

    /// Searches **upward** from `directory` for `swiftmind.plist`.
    /// - Parameters:
    ///   - directory: Starting directory.
    ///   - fileName: Config file name (default `swiftmind.plist`).
    /// - Returns: URL of the first found config or `nil`.
    public static func findUpward(
        startingFrom directory: URL,
        fileName: String = defaultFileName
    ) -> URL? {
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

    /// Returns the best config URL by trying downward first, then upward.
    /// - Parameter startDir: Starting directory (defaults to CWD).
    public static func locateURL(startingFrom startDir: URL? = nil) -> URL? {
        let start = (startDir ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)).standardized
        if let url = findDownward(startingFrom: start) { return url }
        if let url = findUpward(startingFrom: start) { return url }
        return nil
    }
}
