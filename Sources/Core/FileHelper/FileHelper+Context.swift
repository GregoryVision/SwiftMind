//
//  FileHelper+Context.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 29.08.2025.
//

import Foundation
import os.log

public extension FileHelper {
    /// Loads additional context files (files and/or directories), respecting glob filters and size limits.
    ///
    /// - Parameters:
    ///   - inputs: List of paths (relative or absolute).
    ///   - base: Base directory used to resolve relative inputs.
    ///   - options: Context options (include/exclude globs, depth, max bytes, etc.).
    /// - Returns: Concatenated file contents or `nil` if nothing was read.
    static func loadAdditionalContext(
        from inputs: [String],
        base: URL,
        options: ContextOptions
    ) async throws -> String? {
        guard !inputs.isEmpty else { return nil }
        
        // 1) Expand inputs (files/directories) into a list of files
        let files = try expandInputsToFiles(inputs, base: base, options: options)
        guard !files.isEmpty else { return nil }
        
        // 2) Read sequentially while honoring the byte limit
        var total = 0
        var parts: [String] = []
        
        for file in files {
            let data = try Data(contentsOf: file)
            if total + data.count > options.maxBytes { break }
            total += data.count
            
            // Relative path could be used as a header if needed in the future
            // let rel = file.path.replacingOccurrences(of: base.standardized.path + "/", with: "")
            
            // Decode as UTF-8 safely
            let text = String(decoding: data, as: UTF8.self)
            parts.append(text)
        }
        
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: "\n\n")
    }
    
    // MARK: - Expander: files & directories → list of files
    
    /// Expands a list of input paths (files/directories) into a filtered list of files.
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
    
    /// Recursively walks a directory with glob filtering and depth limits.
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
            
            // Fast path exclusion by full relative path
            let rel = entry.path.replacingOccurrences(of: base.standardized.path + "/", with: "")
            if matchesPath(rel, globs: options.excludeGlobs) { continue }
            
            if values.isDirectory == true {
                try walkDirectory(entry, base: base, into: &out, options: options, depth: depth + 1)
            } else if matches(entry, include: options.includeGlobs, exclude: options.excludeGlobs) {
                out.insert(entry)
            }
        }
    }
    
    // MARK: - Glob matching
    
    /// Checks include/exclude globs for a given file URL.
    private static func matches(_ url: URL, include: [String], exclude: [String]) -> Bool {
        let fullPath = url.path
        // Exclude by full path
        if matchesPath(fullPath, globs: exclude) { return false }

        // Include by filename
        if include.isEmpty { return true }
        let name = url.lastPathComponent
        return matchesName(name, globs: include)
    }

    /// Matches a filename against a set of glob patterns (e.g., `*.swift`).
    private static func matchesName(_ name: String, globs: [String]) -> Bool {
        for glob in globs {
            if name.range(of: globToRegex(glob), options: .regularExpression) != nil {
                return true
            }
        }
        return false
    }

    /// Matches a (relative or absolute) path against glob patterns.
    private static func matchesPath(_ path: String, globs: [String]) -> Bool {
        for glob in globs {
            if path.range(of: globToRegex(glob), options: .regularExpression) != nil {
                return true
            }
        }
        return false
    }

    /// Minimal glob → regex conversion:
    /// - `**` → `.*` (match across directories)
    /// - `*`  → `[^/]*` (does not match path separators)
    private static func globToRegex(_ glob: String) -> String {
        var pattern = NSRegularExpression.escapedPattern(for: glob)
        pattern = pattern.replacingOccurrences(of: "\\*\\*", with: ".*")
        pattern = pattern.replacingOccurrences(of: "\\*", with: "[^/]*")
        return "^\(pattern)$"
    }
}
