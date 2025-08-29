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

    func start(_ message: String) {
        guard !isRunning, isatty(fileno(stderr)) == 1 else { return }
        isRunning = true
        Task { await loop(message: message) }
    }

    func stop() {
        isRunning = false
        fputs("\u{1B}[2K\r\n", stderr)
        fflush(stderr)
    }

    private func loop(message: String) async {
        let frames = ["⠋","⠙","⠹","⠸","⠼","⠴","⠦","⠧","⠇","⠏"]
        while isRunning {
            for ch in frames {
                if !isRunning { break }
                fputs("\u{1B}[2K\r🔄 \(message) \(ch)", stderr)
                fflush(stderr)
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
    }
}
