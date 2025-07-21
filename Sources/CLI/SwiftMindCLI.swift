import Core
import Foundation
import ArgumentParser
import os.log
import SwiftSyntax

@main
struct SwiftMind: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "AI CLI for Swift developers",
        subcommands: [Test.self],
        defaultSubcommand: Test.self
    )
}

@available(macOS 13.0, *)
struct Explain: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Explain what Swift code does")
    
    @Argument(help: "The file to explain")
    var filePath: String
    
    func run() async throws {
        let baseURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let resolvedFileURL = URL(fileURLWithPath: filePath, relativeTo: baseURL).standardized
        
        do {
            let (_, code) = try FileHelper.readCode(atAbsolutePath: resolvedFileURL.path)
            let explanation = try await AIUseCases.explainCode(code)
            
            print("📝 Code Explanation:")
            print(explanation)
            
        } catch let error as SwiftMindError {
            print("❌ Error: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
}

// MARK: - AI Review in progress
//struct Review: ParsableCommand {
//    static let configuration = CommandConfiguration(abstract: "Perform AI code review and get improvement suggestions")
//
//    @Argument(help: "The file to review")
//    var filePath: String
//
//    func run() throws {
//        let fileURL = URL(fileURLWithPath: filePath)
//        guard FileManager.default.fileExists(atPath: filePath) else {
//            throw ValidationError("File not found: \(filePath)")
//        }
//
//        let code = try String(contentsOf: fileURL)
//        let prompt = """
//        You are a senior iOS engineer. Review the following Swift code and suggest improvements in formatting, naming, architecture, and performance:
//
//        \(code)
//        """
//
//        let resultText = try performRequest(withPrompt: prompt)
//
//        print("\n--- AI CODE REVIEW ---\n")
//        print(resultText)
//    }
//}


// MARK: - VIPER module generating in progress
//struct GenerateVIPERModule: ParsableCommand {
//}


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
