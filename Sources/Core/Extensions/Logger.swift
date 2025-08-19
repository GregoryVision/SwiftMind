//
//  Logger.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 19.08.2025.
//

import os.log

public extension Logger {
    func logStatistics(collectorCount: Int, commentsCount: Int, processed: Int, skipped: Int) {
        self.info("📊 Statistics:")
        self.info("  • Total declarations found: \(collectorCount)")
        self.info("  • Review comments generated: \(commentsCount)")
        self.info("  • Processed: \(processed)")
        self.info("  • Skipped: \(skipped)")
    }
    func logStatistics(collectorCount: Int, docsCount: Int, processed: Int, skipped: Int) {
        self.info("📊 Statistics:")
        self.info("  • Total declarations found: \(collectorCount)")
        self.info("  • Documentation blocks generated: \(docsCount)")
        self.info("  • Processed: \(processed)")
        self.info("  • Skipped: \(skipped)")
    }
}
