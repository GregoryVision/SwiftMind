//
//  ProgressIndicator.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 16.06.2025.
//

import Foundation
import os.log

// MARK: - Progress Indicator
@available(macOS 13.0, *)
actor ProgressIndicator {
    private var isRunning = false
    private let logger = Logger(subsystem: "SwiftMind", category: "Progress")
    
    func start(message: String) {
        guard !isRunning else { return }
        isRunning = true
        
        Task {
            print("🔄 \(message)", terminator: "")
            fflush(stdout)
            
            while self.isRunning {
                for char in ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"] {
                    if !self.isRunning { break }
                    print("\r🔄 \(message) \(char)", terminator: "")
                    fflush(stdout)
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 sec
                }
            }
            print("\r", terminator: "")
        }
    }
    
    func stop() {
        isRunning = false
    }
}
