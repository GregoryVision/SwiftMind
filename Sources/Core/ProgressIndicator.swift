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
            await self.runLoop(message: message)
        }
    }
    
    private func runLoop(message: String) async {
        print("🔄 \(message)", terminator: "")
        fflush(stdout)
        
        let frames = ["⠋","⠙","⠹","⠸","⠼","⠴","⠦","⠧","⠇","⠏"]
        while isRunning {
            for ch in frames {
                if !isRunning { break }
                print("\r🔄 \(message) \(ch)", terminator: "")
                fflush(stdout)
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            }
        }
        print("\r", terminator: "")
        fflush(stdout)
    }
    
    func stop() {
        isRunning = false
    }
}
