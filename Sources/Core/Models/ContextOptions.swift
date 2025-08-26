//
//  ContextOptions.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 21.08.2025.
//

import Foundation

public struct ContextOptions {
    public var includeGlobs: [String] = ["*.swift"]
    public var excludeGlobs: [String] = ["*/.git/*", "*/Pods/*", "*/DerivedData/*", "*/.build/*"]
    public var followSymlinks: Bool = false
    public var maxBytes: Int = 400_000          // лимит на общий размер контента
    public var maxDepth: Int? = nil             // nil = без ограничений по глубине

    public init(includeGlobs: [String] = ["*.swift"],
                excludeGlobs: [String] = ["*/.git/*", "*/Pods/*", "*/DerivedData/*", "*/.build/*"],
                followSymlinks: Bool = false,
                maxBytes: Int = 400_000,
                maxDepth: Int? = nil) {
        self.includeGlobs = includeGlobs
        self.excludeGlobs = excludeGlobs
        self.followSymlinks = followSymlinks
        self.maxBytes = maxBytes
        self.maxDepth = maxDepth
    }
}
