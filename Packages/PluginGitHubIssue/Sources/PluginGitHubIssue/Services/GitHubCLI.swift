import Foundation
import os
import LumiLoggingKit

/// 本地 `gh` CLI 的可用性检查与 issue 创建封装。
///
/// 所有方法都不抛错——调用方需要的是「成功 / 失败 + 原因」，而不是异常传播。
@MainActor
enum GitHubCLI: SuperLog {
    nonisolated static let emoji = "🐙"
    nonisolated static let verbose = false
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.github-issue",
        category: "GitHubCLI"
    )

    // MARK: - 定位 gh

    /// 在 PATH 里查找 `gh`。找不到返回 `nil`。
    static func locate() -> String? {
        let outcome = runSync(
            executable: "/usr/bin/env",
            arguments: ["which", "gh"],
            workingDirectory: nil
        )
        switch outcome {
        case .success(let output):
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        case .failure:
            return nil
        }
    }

    // MARK: - 认证检查

    /// 调用 `gh auth status`，0 表示已登录。
    static func isAuthenticated(ghPath: String) -> Bool {
        let outcome = runSync(
            executable: ghPath,
            arguments: ["auth", "status"],
            workingDirectory: nil
        )
        switch outcome {
        case .success: return true
        case .failure: return false
        }
    }

    // MARK: - 创建 issue

    struct CreateIssueResult {
        let issueURL: String
        let exitCode: Int32
        let stdout: String
        let stderr: String

        var isSuccess: Bool { exitCode == 0 }
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
        repository: String?
    ) -> CreateIssueResult {
        var args: [String] = ["issue", "create", "--title", title, "--body", body]
        for label in labels {
            args.append(contentsOf: ["--label", label])
        }
        if let repository, !repository.isEmpty {
            args.append(contentsOf: ["--repo", repository])
        }

        let outcome = runSync(
            executable: ghPath,
            arguments: args,
            workingDirectory: workingDirectory
        )
        switch outcome {
        case .success(let output):
            return CreateIssueResult(
                issueURL: output.trimmingCharacters(in: .whitespacesAndNewlines),
                exitCode: 0,
                stdout: output,
                stderr: ""
            )
        case .failure(let failure):
            return CreateIssueResult(
                issueURL: "",
                exitCode: failure.code,
                stdout: failure.stdout,
                stderr: failure.stderr
            )
        }
    }

    // MARK: - 同步执行

    private struct ProcessFailure {
        let code: Int32
        let stdout: String
        let stderr: String
    }

    private enum RunOutcome {
        case success(String)
        case failure(ProcessFailure)
    }

    private static func runSync(
        executable: String,
        arguments: [String],
        workingDirectory: String?
    ) -> RunOutcome {
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

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return .failure(ProcessFailure(
                code: -1,
                stdout: "",
                stderr: error.localizedDescription
            ))
        }

        let stdout = String(
            decoding: outPipe.fileHandleForReading.readDataToEndOfFile(),
            as: UTF8.self
        )
        let stderr = String(
            decoding: errPipe.fileHandleForReading.readDataToEndOfFile(),
            as: UTF8.self
        )
        let code = process.terminationStatus
        if code == 0 {
            return .success(stdout)
        }
        return .failure(ProcessFailure(code: code, stdout: stdout, stderr: stderr))
    }
}
