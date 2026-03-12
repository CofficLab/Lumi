import Foundation
import Combine
import OSLog
import MagicKit

/// Shell 服务：负责执行 Shell 命令
///
/// 设计原则：
/// - 不在主线程上运行，所有操作都是异步的
/// - 通过 Combine Publishers 通知状态变化
/// - ViewModel 层负责将状态暴露给 UI
/// - 单例模式，全局共享一个 Shell 服务实例
///
/// 线程安全：此类通过方法内部同步保证线程安全，因此可以安全地在并发代码中使用
class ShellService: SuperLog {

    // MARK: - Logger

    nonisolated static let emoji = "🐚"
    nonisolated static let verbose = true

    // MARK: - Singleton

    static let shared = ShellService()

    private init() {
        if Self.verbose {
            os_log("\(Self.t)✅ Shell 服务已初始化（单例）")
        }
    }

    // MARK: - Combine Publishers

    /// Shell 输出变化通知
    let outputPublisher = PassthroughSubject<String, Never>()

    /// Shell 运行状态变化通知
    let runningStatePublisher = PassthroughSubject<Bool, Never>()

    // MARK: - Properties

    /// 当前工作目录
    var currentDirectory: String = FileManager.default.homeDirectoryForCurrentUser.path

    /// 当前输出（供同步访问）
    private(set) var currentOutput: String = ""

    /// 是否正在运行（供同步访问）
    private(set) var isRunning: Bool = false

    @MainActor
    func execute(_ command: String) async throws -> String {
        // 更新状态并通过 Publisher 通知
        isRunning = true
        runningStatePublisher.send(true)

        defer {
            isRunning = false
            runningStatePublisher.send(false)
        }

        // Capture currentDirectory on MainActor before entering detached task
        let workingDirectory = self.currentDirectory

        return try await Task.detached(priority: .userInitiated) {
            let process = Process()
            let pipe = Pipe()
            let errorPipe = Pipe()

            // Use zsh for shell execution
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", command]

            // Set current working directory
            process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)

            // Set environment
            var env = ProcessInfo.processInfo.environment
            env["TERM"] = "xterm-256color"
            env["LANG"] = "en_US.UTF-8"
            // Add Homebrew path
            env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            process.environment = env

            process.standardOutput = pipe
            process.standardError = errorPipe

            try process.run()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

            process.waitUntilExit()

            let output = String(data: data, encoding: .utf8) ?? ""
            let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

            let result = output + (errorOutput.isEmpty ? "" : "\nError:\n\(errorOutput)")

            return result
        }.value
    }
}

// MARK: - Sendable Conformance

extension ShellService: @unchecked Sendable {
    @MainActor
    func updateWorkingDirectory(_ path: String) {
        var targetPath = path
        if path.hasPrefix("~") {
            targetPath = (path as NSString).expandingTildeInPath
        }

        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: targetPath, isDirectory: &isDir), isDir.boolValue {
            self.currentDirectory = targetPath
        }
    }
}
