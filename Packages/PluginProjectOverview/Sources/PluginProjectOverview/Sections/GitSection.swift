import Foundation
import KitShell

/// Git 信息检测
public enum GitSection {
    /// 渲染 Git 仓库信息
    public static func render(at root: URL) -> String {
        // 传入的可能是仓库子目录（或被 worktree/submodule 的 `.git` 文件指向上级），
        // 只检查 `root/.git` 会把它们误判为非仓库。交给 Git 按正常规则向上发现工作树。
        guard runGit(args: ["rev-parse", "--is-inside-work-tree"], in: root)?
            .trimmingCharacters(in: .whitespacesAndNewlines) == "true" else {
            return "Not a Git repository."
        }

        let branch = runGit(args: ["branch", "--show-current"], in: root)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let remote = runGit(args: ["remote", "get-url", "origin"], in: root)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let statusPorcelain = runGit(args: ["status", "--porcelain"], in: root)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let isClean = (statusPorcelain ?? "").isEmpty

        var lines: [String] = ["Repository: Yes"]
        if let b = branch, !b.isEmpty { lines.append("Branch: \(b)") }
        if let r = remote, !r.isEmpty { lines.append("Remote: \(r)") }
        lines.append("Status: \(isClean ? "Clean" : "Uncommitted changes")")
        return lines.joined(separator: "\n")
    }

    private static func runGit(args: [String], in directory: URL) -> String? {
        let semaphore = DispatchSemaphore(value: 0)
        let box = GitSectionLockedStringBox()
        Task {
            let result = try? await Shell.execute(
                executable: "/usr/bin/git",
                arguments: args,
                options: ShellOptions(
                    workingDirectory: directory.path,
                    environment: [
                        "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
                    ],
                    throwsOnError: false
                )
            )
            box.set(result?.exitCode == 0 ? result?.stdout : nil)
            semaphore.signal()
        }
        semaphore.wait()
        return box.get()
    }
}

/// 线程安全的 String Box
private final class GitSectionLockedStringBox: @unchecked Sendable {
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
