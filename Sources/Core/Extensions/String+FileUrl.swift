//
//  String+FileUrl.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 11.08.2025.
//
import Foundation

public extension String {
    var fileURL: URL {
        URL(fileURLWithPath: self)
    }

    func fileURL(isDirectory: Bool) -> URL {
        URL(fileURLWithPath: self, isDirectory: isDirectory)
    }
}
