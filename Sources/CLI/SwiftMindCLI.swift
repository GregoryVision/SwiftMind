import Core
import Foundation
import ArgumentParser
import os.log

import SwiftSyntax
import SwiftParser

// MARK: - VIPER module generating in progress
//struct GenerateVIPERModule: ParsableCommand {
//}

// ToDo: Вынести всю логику в Core

@main
struct SwiftMindCLI: ParsableCommand {
    
    static let configuration = CommandConfiguration(
        abstract: "AI CLI for Swift developers",
        subcommands: [Test.self],
        defaultSubcommand: Test.self
    )
    static let config: SwiftMindConfigProtocol = SwiftMindConfig.load()
    nonisolated(unsafe) static let ollamaBridge: OllamaBridgeProtocol = OllamaBridge(maxRetries: config.maxRetries, timeoutSeconds: config.timeoutSeconds)
    nonisolated(unsafe) static let aiUseCases: AIUseCasesProtocol = makeUseCases()
    
    static func makeUseCases() -> AIUseCasesProtocol {
        let config = SwiftMindConfig.load()
        let ollama = OllamaBridge(maxRetries: config.maxRetries, timeoutSeconds: config.timeoutSeconds)
        return AIUseCases(
            generateTests: GenerateTestsUseCaseImpl(ollama: ollama, config: config),
            reviewCode: ReviewCodeUseCaseImpl(ollama: ollama, config: config),
            explainCode: ExplainCodeUseCaseImpl(ollama: ollama, config: config),
            generateDocs: GenerateDocumentationUseCaseImpl(ollama: ollama, config: config)
        )
    }
}




//func countTokens(for text: String) -> Int {
//    // Примерная оценка: 1 токен ≈ 3.5 символа для Swift-кода
//    return text.count / 3
//}




//// swiftai/Commands/EnableAutostart.swift
//
//
//struct EnableAutostart: ParsableCommand {
//    static let configuration = CommandConfiguration(
//        abstract: "Добавляет Ollama в автозагрузку macOS"
//    )
//
//    func run() throws {
//        let launchAgentsPath = FileManager.default.homeDirectoryForCurrentUser
//            .appendingPathComponent("Library/LaunchAgents")
//        let plistPath = launchAgentsPath.appendingPathComponent("com.swiftai.ollama.plist")
//
//        let plistContents = """
//        <?xml version=\"1.0\" encoding=\"UTF-8\"?>
//        <!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\"
//           \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
//        <plist version=\"1.0\">
//        <dict>
//            <key>Label</key>
//            <string>com.swiftai.ollama</string>
//            <key>ProgramArguments</key>
//            <array>
//                <string>/usr/local/bin/ollama</string>
//                <string>run</string>
//                <string>codellama</string>
//            </array>
//            <key>RunAtLoad</key>
//            <true/>
//            <key>KeepAlive</key>
//            <true/>
//        </dict>
//        </plist>
//        """
//
//        try FileManager.default.createDirectory(at: launchAgentsPath, withIntermediateDirectories: true)
//        try plistContents.write(to: plistPath, atomically: true, encoding: .utf8)
//
//        let task = Process()
//        task.launchPath = "/bin/launchctl"
//        task.arguments = ["load", plistPath.path]
//        try task.run()
//
//        print("✅ Ollama будет запускаться автоматически при старте macOS.")
//    }
//}
//
//
//// swiftai/Commands/DisableAutostart.swift
//
//import Foundation
//import ArgumentParser
//
//struct DisableAutostart: ParsableCommand {
//    static let configuration = CommandConfiguration(
//        abstract: "Удаляет Ollama из автозагрузки macOS"
//    )
//
//    func run() throws {
//        let plistPath = FileManager.default.homeDirectoryForCurrentUser
//            .appendingPathComponent("Library/LaunchAgents/com.swiftai.ollama.plist")
//
//        if FileManager.default.fileExists(atPath: plistPath.path) {
//            let task = Process()
//            task.launchPath = "/bin/launchctl"
//            task.arguments = ["unload", plistPath.path]
//            try task.run()
//
//            try FileManager.default.removeItem(at: plistPath)
//            print("🛑 Автозапуск Ollama отключён.")
//        } else {
//            print("ℹ️ Автозапуск Ollama уже отключён.")
//        }
//    }
//}
