//
//  DocumentationReturnFormat.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 07.07.2025.
//

import Foundation
import ArgumentParser

public enum DocumentationReturnFormat: String, ExpressibleByArgument {
    case separateBlocks, fullCode
}
