import Foundation
import SuperLogKit

import os

/// Go 命令执行器
///
/// 封装 `go build`、`go test`、`go fmt`、`go mod tidy` 等命令的 Process 调用。
/// 使用 actor 保证同一时间只有一个命令在执行。
public actor GoRunner: SuperLog {
    public nonisolated static let emoji = "🏃"
    public nonisolated static let verbose: Bool = false
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.go-editor.runner"
    )

    // MARK: - 状态

    /// 当前正在运行的进程
    private var currentProcess: Process?

    /// 是否正在执行
    public var isRunning: Bool {
        currentProcess != nil && currentProcess!.isRunning
    }

    // MARK: - 执行命令

    /// 执行命令并返回输出结果
    public func execute(
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

        if Self.verbose {
            Self.logger.info("\(Self.t)执行: go \(command) \(arguments.joined(separator: " "))")
        }

        async let stdoutData = GoRunnerOutputCollector.readData(from: stdoutPipe)
        async let stderrData = GoRunnerOutputCollector.readData(from: stderrPipe)

        let exitCode: Int32
        do {
            exitCode = try await Self.runAndWait(process)
        } catch {
            try? stdoutPipe.fileHandleForWriting.close()
            try? stderrPipe.fileHandleForWriting.close()
            currentProcess = nil
            return GoRunResult(
                exitCode: -1,
                stdout: "",
                stderr: error.localizedDescription
            )
        }
        let output = await (stdoutData, stderrData)

        currentProcess = nil

        return GoRunResult(
            exitCode: Int(exitCode),
            stdout: String(data: output.0, encoding: .utf8) ?? "",
            stderr: String(data: output.1, encoding: .utf8) ?? ""
        )
    }

    public func execute(
        _ toolCommand: any GoToolCommand,
        workingDirectory: String
    ) async -> GoRunResult {
        await execute(
            command: toolCommand.command,
            arguments: toolCommand.arguments,
            workingDirectory: workingDirectory
        )
    }

    /// 取消当前正在执行的进程
    public func cancel() {
        guard let process = currentProcess, process.isRunning else { return }
        process.terminate()
        currentProcess = nil
        if Self.verbose {
            Self.logger.info("\(Self.t)已取消正在执行的命令")
        }
    }

    private nonisolated static func runAndWait(_ process: Process) async throws -> Int32 {
        try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { terminatedProcess in
                continuation.resume(returning: terminatedProcess.terminationStatus)
            }
            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                continuation.resume(throwing: error)
            }
        }
    }
}

enum GoRunnerOutputCollector {
    static func readData(from pipe: Pipe) async -> Data {
        await withCheckedContinuation { continuation in
            let handle = pipe.fileHandleForReading
            DispatchQueue.global(qos: .utility).async {
                continuation.resume(returning: handle.readDataToEndOfFile())
            }
        }
    }
}
