//
//  FixCodeUseCase.swift
//  SwiftMind
//
//  Created by Gregory Tolkachev on 15.09.2025.
//

public protocol FixCodeUseCase {
    /// Возвращает ИСКЛЮЧИТЕЛЬНО исходник исправленной функции (с той же сигнатурой).
    /// Если правки не требуются — может вернуть "__NO_CHANGE__".
    func fixSingleFunction(functionSource: String,
                           goals: String?,
                           promptMaxLength: Int) async throws -> String
}

public struct FixCodeUseCaseImpl: FixCodeUseCase {
    private let ollama: OllamaBridgeProtocol
    private let config: SwiftMindConfigProtocol

    public init(ollama: OllamaBridgeProtocol, config: SwiftMindConfigProtocol) {
        self.ollama = ollama
        self.config = config
    }

    private var systemRole: String {
        """
        You are a senior Swift engineer. Make minimal, safe fixes.
        Preserve API/signature, semantics, and surrounding style.
        Prefer clarity, thread-safety, ARC-safety, and correct error handling.
        """
    }

    public func fixSingleFunction(functionSource: String,
                                  goals: String?,
                                  promptMaxLength: Int) async throws -> String {

        let goalsText = goals.flatMap { g in
            "Additional goals (optional, prioritize safety): \(g)"
        } ?? ""

        // Важно: просим вернуть только код функции (никаких импортов/объяснений)
        let prompt = """
        \(systemRole)

        Fix the SINGLE Swift function below. Make minimal changes that improve:
        - memory safety (avoid retain cycles, capture lists where needed)
        - thread safety (e.g., main-thread UI)
        - error handling and resource management
        - readability and Swift best practices

        STRICT OUTPUT:
        - Return ONLY the fixed function source code.
        - Keep the EXACT same signature (name, params, throws/async, generics, attributes).
        - Do NOT add imports or surrounding types.
        - Do NOT add comments unless necessary to clarify non-obvious change.

        \(goalsText)

        Function to fix:
        \(functionSource)
        """

        let (sanitized, _) = try PromptSanitizer.sanitize(prompt, maxLength: promptMaxLength)
        return try await ollama.send(prompt: sanitized, model: config.defaultModel)
    }
}
