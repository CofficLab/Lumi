import Foundation
import MagicKit

/// Go 环境解析器
///
/// 探测 Go 工具链路径（go、gopls、gofumpt）并解析 `go env`。
struct GoEnvResolver: SuperLog {
    nonisolated static let emoji = "🔧"

    /// 探测到的 go 可执行路径
    static var goPath: String? {
        findCommand("go")
    }

    /// 探测到的 gopls 可执行路径
    static var goplsPath: String? {
        findCommand("gopls")
    }

    /// 探测到的 gofumpt 可执行路径
    static var gofumptPath: String? {
        findCommand("gofumpt")
    }

    /// 解析 `go env GOPATH`
    static func resolveGOPATH() -> String? {
        goEnv("GOPATH")
    }

    /// 解析 `go env GOROOT`
    static func resolveGOROOT() -> String? {
        goEnv("GOROOT")
    }

    // MARK: - Private

    private static func findCommand(_ command: String) -> String? {
        try? runShellCommand("/usr/bin/which", args: [command])?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func goEnv(_ key: String) -> String? {
        guard let go = goPath else { return nil }
        return try? runShellCommand(go, args: ["env", key])?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func runShellCommand(_ path: String, args: [String]) throws -> String? {
        let process = Process()
        process.executableURL = URL(filePath: path)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }
}
