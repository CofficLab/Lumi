import Foundation
import os
import LumiLoggingKit

/// 本地 `gh` CLI 的可用性检查与 issue 创建封装。
///
/// 所有方法都不抛错——调用方需要的是「成功 / 失败 + 原因」，而不是异常传播。
///
/// 外部进程一律在后台线程等待：`gh auth status` 与 `gh issue create` 都会访问
/// 网络，若在 MainActor 上 `waitUntilExit()`，慢网络会冻结整个应用。每次执行
/// 都带超时，并响应 Task 取消（终止子进程后返回 `.cancelled`）。
enum GitHubCLI: SuperLog {
    nonisolated static let emoji = "🐙"
    nonisolated static let verbose = false
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.github-issue",
        category: "GitHubCLI"
    )

    /// 本地查询类命令（`which`、`auth status`）的超时。
    static let probeTimeout: TimeInterval = 30
    /// 创建 Issue 涉及网络写操作，给更长的窗口。
    static let createTimeout: TimeInterval = 120

    // MARK: - 定位 gh

    /// 在 PATH 里查找 `gh`。找不到返回 `nil`。
    static func locate(timeout: TimeInterval = probeTimeout) async -> String? {
        let outcome = await run(
            executable: "/usr/bin/env",
            arguments: ["which", "gh"],
            workingDirectory: nil,
            timeout: timeout
        )
        switch outcome {
        case .success(let output):
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        case .failure, .timedOut, .cancelled:
            return nil
        }
    }

    // MARK: - 认证检查

    /// 调用 `gh auth status`，0 表示已登录。
    static func isAuthenticated(ghPath: String, timeout: TimeInterval = probeTimeout) async -> Bool {
        let outcome = await run(
            executable: ghPath,
            arguments: ["auth", "status"],
            workingDirectory: nil,
            timeout: timeout
        )
        if case .success = outcome { return true }
        return false
    }

    // MARK: - 创建 issue

    struct CreateIssueResult {
        let issueURL: String
        let exitCode: Int32
        let stdout: String
        let stderr: String
        let wasTimedOut: Bool
        let wasCancelled: Bool

        var isSuccess: Bool { exitCode == 0 && !wasTimedOut && !wasCancelled }
    }

    /// 调用 `gh issue create`，返回结果（exitCode + 输出）。
    ///
    /// 非交互：`--web` 不开、`--body` 直接传；`gh` 在非 TTY 下只打印 issue URL 到 stdout。
    static func createIssue(
        ghPath: String,
        workingDirectory: String?,
        title: String,
        body: String,
        labels: [String],
        repository: String?,
        timeout: TimeInterval = createTimeout
    ) async -> CreateIssueResult {
        var args: [String] = ["issue", "create", "--title", title, "--body", body]
        for label in labels {
            args.append(contentsOf: ["--label", label])
        }
        if let repository, !repository.isEmpty {
            args.append(contentsOf: ["--repo", repository])
        }

        let outcome = await run(
            executable: ghPath,
            arguments: args,
            workingDirectory: workingDirectory,
            timeout: timeout
        )
        switch outcome {
        case .success(let output):
            return CreateIssueResult(
                issueURL: output.trimmingCharacters(in: .whitespacesAndNewlines),
                exitCode: 0,
                stdout: output,
                stderr: "",
                wasTimedOut: false,
                wasCancelled: false
            )
        case .failure(let failure):
            return CreateIssueResult(
                issueURL: "",
                exitCode: failure.code,
                stdout: failure.stdout,
                stderr: failure.stderr,
                wasTimedOut: false,
                wasCancelled: false
            )
        case .timedOut:
            return CreateIssueResult(
                issueURL: "",
                exitCode: -1,
                stdout: "",
                stderr: "`gh issue create` timed out after \(Int(timeout))s.",
                wasTimedOut: true,
                wasCancelled: false
            )
        case .cancelled:
            return CreateIssueResult(
                issueURL: "",
                exitCode: -1,
                stdout: "",
                stderr: "`gh issue create` was cancelled.",
                wasTimedOut: false,
                wasCancelled: true
            )
        }
    }

    // MARK: - 异步执行

    struct ProcessFailure: Equatable {
        let code: Int32
        let stdout: String
        let stderr: String
    }

    enum RunOutcome: Equatable {
        case success(String)
        case failure(ProcessFailure)
        case timedOut
        case cancelled
    }

    /// 在后台线程运行子进程并等待退出，不占用调用方执行器。
    ///
    /// 超时或取消都会先终止子进程再返回，保证等待必然结束。
    static func run(
        executable: String,
        arguments: [String],
        workingDirectory: String?,
        timeout: TimeInterval
    ) async -> RunOutcome {
        let state = ProcessRunState()

        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: executable)
                    process.arguments = arguments
                    if let cwd = workingDirectory {
                        process.currentDirectoryURL = URL(fileURLWithPath: cwd)
                    }
                    let outPipe = Pipe()
                    let errPipe = Pipe()
                    process.standardOutput = outPipe
                    process.standardError = errPipe
                    // 不让 gh 读到 stdin，避免它进入交互模式（TTY 检测通常基于 isatty，
                    // 但显式关闭 stdin 更安全）。
                    process.standardInput = FileHandle.nullDevice

                    state.register(process)
                    do {
                        try process.run()
                    } catch {
                        state.finish()
                        continuation.resume(returning: .failure(ProcessFailure(
                            code: -1,
                            stdout: "",
                            stderr: error.localizedDescription
                        )))
                        return
                    }

                    if timeout > 0 {
                        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + timeout) {
                            state.timeout()
                        }
                    }

                    process.waitUntilExit()

                    let stdout = String(
                        decoding: outPipe.fileHandleForReading.readDataToEndOfFile(),
                        as: UTF8.self
                    )
                    let stderr = String(
                        decoding: errPipe.fileHandleForReading.readDataToEndOfFile(),
                        as: UTF8.self
                    )
                    let flags = state.finish()

                    let outcome: RunOutcome
                    if flags.cancelled {
                        outcome = .cancelled
                    } else if flags.timedOut {
                        outcome = .timedOut
                    } else if process.terminationStatus == 0 {
                        outcome = .success(stdout)
                    } else {
                        outcome = .failure(ProcessFailure(
                            code: process.terminationStatus,
                            stdout: stdout,
                            stderr: stderr
                        ))
                    }
                    continuation.resume(returning: outcome)
                }
            }
        } onCancel: {
            state.cancel()
        }
    }
}

// MARK: - 进程状态

/// 跨线程记录子进程与「超时 / 取消」标记，保证只有第一个结束原因生效。
private final class ProcessRunState: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var isFinished = false
    private var didTimeOut = false
    private var didCancel = false

    func register(_ process: Process) {
        lock.lock()
        self.process = process
        let shouldCancel = didCancel
        lock.unlock()
        if shouldCancel, process.isRunning {
            process.terminate()
        }
    }

    func timeout() {
        lock.lock()
        guard !isFinished, !didCancel else {
            lock.unlock()
            return
        }
        didTimeOut = true
        let process = self.process
        lock.unlock()
        if let process, process.isRunning {
            process.terminate()
        }
    }

    func cancel() {
        lock.lock()
        guard !isFinished, !didTimeOut else {
            lock.unlock()
            return
        }
        didCancel = true
        let process = self.process
        lock.unlock()
        if let process, process.isRunning {
            process.terminate()
        }
    }

    func finish() -> (timedOut: Bool, cancelled: Bool) {
        lock.lock()
        defer { lock.unlock() }
        isFinished = true
        return (didTimeOut, didCancel)
    }
}
