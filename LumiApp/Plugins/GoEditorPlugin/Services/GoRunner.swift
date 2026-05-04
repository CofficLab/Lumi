import Foundation
import MagicKit
import os

/// Go 命令执行器
///
/// 封装 `go build`、`go test`、`go fmt`、`go mod tidy` 等命令的 Process 调用。
/// 使用 actor 保证同一时间只有一个命令在执行。
actor GoRunner: SuperLog {
    nonisolated static let emoji = "🏃"
    nonisolated static let verbose = false
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.go-editor.runner"
    )

    // MARK: - 状态

    /// 当前正在运行的进程
    private var currentProcess: Process?

    /// 是否正在执行
    var isRunning: Bool {
        currentProcess != nil && currentProcess!.isRunning
    }

    // MARK: - 执行命令

    /// 执行命令并返回输出结果
    func execute(
        command: String,
        arguments: [String] = [],
        workingDirectory: String
    ) async -> GoRunResult {
        guard let execPath = GoEnvResolver.goPath else {
            return GoRunResult(
                exitCode: -1,
                stdout: "",
                stderr: "go command not found"
            )
        }

        // 取消正在运行的进程
        cancel()

        let process = Process()
        process.executableURL = URL(filePath: execPath)
        process.arguments = [command] + arguments
        process.currentDirectoryURL = URL(filePath: workingDirectory)

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        currentProcess = process

        if GoEditorPlugin.verbose {
            GoEditorPlugin.logger.info("\(Self.t)执行: go \(command) \(arguments.joined(separator: " "))")
        }

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            currentProcess = nil
            return GoRunResult(
                exitCode: -1,
                stdout: "",
                stderr: error.localizedDescription
            )
        }

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        currentProcess = nil

        return GoRunResult(
            exitCode: Int(process.terminationStatus),
            stdout: String(data: stdoutData, encoding: .utf8) ?? "",
            stderr: String(data: stderrData, encoding: .utf8) ?? ""
        )
    }

    /// 取消当前正在执行的进程
    func cancel() {
        guard let process = currentProcess, process.isRunning else { return }
        process.terminate()
        currentProcess = nil
        if GoEditorPlugin.verbose {
            GoEditorPlugin.logger.info("\(Self.t)已取消正在执行的命令")
        }
    }
}
