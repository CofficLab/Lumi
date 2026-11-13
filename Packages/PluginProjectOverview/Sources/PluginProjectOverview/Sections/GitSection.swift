import Foundation
import KitShell

/// Git 信息检测
public enum GitSection {
    /// 渲染 Git 仓库信息
    ///
    /// - Note: 这里的 git 调用全部走 async/await。
    ///   原先用 `DispatchSemaphore.wait()` 把 async 的 `Shell.execute`
    ///   桥回同步代码，会**阻塞一个协作线程**：Swift 协作线程池是定宽的
    ///   且与 `MainActor` 共用，被占住的线程无法推进 UI 任务，
    ///   最坏会把池饿死（见 issue #1288）。
    public static func render(at root: URL) async -> String {
        // 传入的可能是仓库子目录（或被 worktree/submodule 的 `.git` 文件指向上级），
        // 只检查 `root/.git` 会把它们误判为非仓库。交给 Git 按正常规则向上发现工作树。
        guard await runGit(args: ["rev-parse", "--is-inside-work-tree"], in: root)?
            .trimmingCharacters(in: .whitespacesAndNewlines) == "true" else {
            return "Not a Git repository."
        }

        let branch = await runGit(args: ["branch", "--show-current"], in: root)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let remote = await runGit(args: ["remote", "get-url", "origin"], in: root)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let statusPorcelain = await runGit(args: ["status", "--porcelain"], in: root)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let isClean = (statusPorcelain ?? "").isEmpty

        var lines: [String] = ["Repository: Yes"]
        if let b = branch, !b.isEmpty { lines.append("Branch: \(b)") }
        if let r = remote, !r.isEmpty { lines.append("Remote: \(r)") }
        lines.append("Status: \(isClean ? "Clean" : "Uncommitted changes")")
        return lines.joined(separator: "\n")
    }

    /// 单次 git 调用的超时（秒）。
    ///
    /// - Important: 必须有上界。没有超时时，大仓库上的
    ///   `git status --porcelain`、被占用的索引或网络卷会让调用无限期挂住
    ///   （见 issue #1288）。
    private static let gitTimeout: TimeInterval = 10

    private static func runGit(args: [String], in directory: URL) async -> String? {
        let result = try? await Shell.execute(
            executable: "/usr/bin/git",
            arguments: args,
            options: ShellOptions(
                workingDirectory: directory.path,
                environment: [
                    "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
                ],
                timeout: gitTimeout,
                throwsOnError: false
            )
        )
        return result?.exitCode == 0 ? result?.stdout : nil
    }
}
