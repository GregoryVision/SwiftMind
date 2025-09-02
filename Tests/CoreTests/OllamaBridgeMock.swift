//
//  OllamaBridgeMock.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 02.09.2025.
//
import Core

final class OllamaBridgeMock: OllamaBridgeProtocol {
    var capturedPrompt: String?
    var result: Result<String, Error> = .success("ok")
    func send(prompt: String, model: String) async throws -> String {
        capturedPrompt = prompt
        return try result.get()
    }

}
