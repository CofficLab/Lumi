import Foundation
import Testing
@testable import PluginGitHubIssue

/// `GitHubCLI` 子进程执行的行为契约。
///
/// 这里只用 `/bin/echo`、`/bin/sh`、`/bin/sleep`，不依赖 `gh` 或网络。
@Suite("GitHubCLI 子进程执行")
struct GitHubCLIRunTests {

    @Test("收集 stdout 与退出码")
    func capturesStandardOutput() async {
        let outcome = await GitHubCLI.run(
            executable: "/bin/echo",
            arguments: ["hello"],
            workingDirectory: nil,
            timeout: 5
        )

        #expect(outcome == .success("hello\n"))
    }

    @Test("非零退出保留退出码与 stderr")
    func reportsNonZeroExit() async {
        let outcome = await GitHubCLI.run(
            executable: "/bin/sh",
            arguments: ["-c", "echo boom >&2; exit 3"],
            workingDirectory: nil,
            timeout: 5
        )

        guard case .failure(let failure) = outcome else {
            Issue.record("expected failure, got \(outcome)")
            return
        }
        #expect(failure.code == 3)
        #expect(failure.stderr.contains("boom"))
    }

    @Test("超时会终止子进程并结束等待（**回归 #1049**）")
    func timeoutTerminatesProcess() async {
        let started = Date()
        let outcome = await GitHubCLI.run(
            executable: "/bin/sleep",
            arguments: ["5"],
            workingDirectory: nil,
            timeout: 0.2
        )

        #expect(outcome == .timedOut)
        #expect(Date().timeIntervalSince(started) < 3)
    }

    @Test("取消 Task 会终止子进程并结束等待（**回归 #1049**）")
    func cancellationTerminatesProcess() async {
        let started = Date()
        let task = Task {
            await GitHubCLI.run(
                executable: "/bin/sleep",
                arguments: ["5"],
                workingDirectory: nil,
                timeout: 30
            )
        }

        try? await Task.sleep(nanoseconds: 200_000_000)
        task.cancel()
        let outcome = await task.value

        #expect(outcome == .cancelled)
        #expect(Date().timeIntervalSince(started) < 3)
    }

    @Test("创建失败不会被误判为成功")
    func failedCreationIsNotSuccess() async {
        let result = await GitHubCLI.createIssue(
            ghPath: "/usr/bin/false",
            workingDirectory: nil,
            title: "Title",
            body: "Body",
            labels: [],
            repository: nil,
            timeout: 5
        )

        #expect(!result.isSuccess)
        #expect(!result.wasTimedOut)
        #expect(!result.wasCancelled)
        #expect(result.exitCode != 0)
    }
}
