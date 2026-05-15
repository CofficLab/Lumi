import Foundation
import MagicKit
import ShellKit

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
        Shell.findCommandSync(command)
    }

    private static func goEnv(_ key: String) -> String? {
        guard let go = goPath else { return nil }
        return try? runShellCommand(go, args: ["env", key])?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func runShellCommand(_ path: String, args: [String]) throws -> String? {
        runShellCommandSync(path, args: args)
    }

    private static func runShellCommandSync(_ path: String, args: [String]) -> String? {
        let semaphore = DispatchSemaphore(value: 0)
        let box = GoLockedStringBox()
        Task {
            let result = try? await Shell.execute(
                executable: path,
                arguments: args,
                options: ShellOptions(throwsOnError: false)
            )
            box.set(result?.exitCode == 0 ? result?.stdout : nil)
            semaphore.signal()
        }
        semaphore.wait()
        return box.get()
    }
}

private final class GoLockedStringBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value: String?

    func set(_ value: String?) {
        lock.lock()
        self.value = value
        lock.unlock()
    }

    func get() -> String? {
        lock.lock()
        let result = value
        lock.unlock()
        return result
    }
}
