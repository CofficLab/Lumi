import Foundation
import MagicKit
import OSLog

/// Git 服务
///
/// 封装 Git 命令的执行和结果解析。
final class GitService: @unchecked Sendable, SuperLog {
    nonisolated static let verbose = false
    nonisolated static let emoji = "📦"
    static let shared = GitService()

    private init() {}

    // MARK: - Git Status

    func getStatus(path: String?) async throws -> GitStatus {
        let workDir = path.map { URL(fileURLWithPath: $0) } ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

        // 获取分支信息
        let branch = try await runGitCommand(args: ["branch", "--show-current"], in: workDir)

        // 获取远程信息
        let remote = try? await runGitCommand(args: ["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"], in: workDir)

        // 获取状态信息（porcelain 格式，易于解析）
        let statusOutput = try await runGitCommand(args: ["status", "--porcelain"], in: workDir)

        var modified: [String] = []
        var added: [String] = []
        var deleted: [String] = []
        var renamed: [String] = []
        var staged: [String] = []

        for line in statusOutput.components(separatedBy: "\n").filtering({ !$0.isEmpty }) {
            let status = String(line.prefix(2))
            let file = String(line.dropFirst(3))

            switch status {
            case " M", "? ":
                modified.append(file)
            case "A ", "AM":
                added.append(file)
            case " D":
                deleted.append(file)
            case "R ":
                renamed.append(file)
            case "M ", "A ", "D ", "R ":
                staged.append(file)
            default:
                break
            }
        }

        return GitStatus(
            branch: branch.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines),
            remote: remote?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines),
            modified: modified,
            added: added,
            deleted: deleted,
            renamed: renamed,
            staged: staged
        )
    }

    // MARK: - Git Diff

    func getDiff(path: String?, staged: Bool, file: String?) async throws -> GitDiff {
        let workDir = path.map { URL(fileURLWithPath: $0) } ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

        var args: [String] = ["diff", "--color=never"]

        if staged {
            args.append("--staged")
        }

        if let file = file {
            args.append("--")
            args.append(file)
        }

        let content = try await runGitCommand(args: args, in: workDir)

        // 获取统计信息
        var stats: GitDiffStats? = nil
        do {
            var statsArgs = ["diff", "--numstat"]
            if staged {
                statsArgs.append("--staged")
            }
            if let file = file {
                statsArgs.append("--")
                statsArgs.append(file)
            }
            let statsOutput = try await runGitCommand(args: statsArgs, in: workDir)

            var filesChanged = 0
            var insertions = 0
            var deletions = 0

            for line in statsOutput.components(separatedBy: "\n").filtering({ !$0.isEmpty }) {
                let parts = line.components(separatedBy: "\t")
                if parts.count >= 3 {
                    filesChanged += 1
                    if parts[0] != "-" {
                        insertions += Int(parts[0]) ?? 0
                    }
                    if parts[1] != "-" {
                        deletions += Int(parts[1]) ?? 0
                    }
                }
            }

            if filesChanged > 0 {
                stats = GitDiffStats(filesChanged: filesChanged, insertions: insertions, deletions: deletions)
            }
        } catch {
            // 忽略统计信息获取失败
        }

        return GitDiff(content: content, stats: stats)
    }

    // MARK: - Git Log

    func getLog(path: String?, count: Int, branch: String?, file: String?) async throws -> [GitCommitLog] {
        let workDir = path.map { URL(fileURLWithPath: $0) } ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

        var args: [String] = [
            "log",
            "-\(count)",
            "--pretty=format:%H|%an|%ae|%ai|%s",
        ]

        if let branch = branch {
            args.append(branch)
        }

        if let file = file {
            args.append("--")
            args.append(file)
        }

        let output = try await runGitCommand(args: args, in: workDir)

        var logs: [GitCommitLog] = []

        for line in output.components(separatedBy: "\n").filtering({ !$0.isEmpty }) {
            let parts = line.components(separatedBy: "|")
            if parts.count >= 5 {
                logs.append(GitCommitLog(
                    hash: parts[0],
                    author: parts[1],
                    email: parts[2],
                    date: parts[3],
                    message: parts.dropFirst(4).joined(separator: "|")
                ))
            }
        }

        return logs
    }

    // MARK: - Helper

    private func runGitCommand(args: String..., in directory: URL) async throws -> String {
        try await runGitCommand(args: args, in: directory)
    }

    private func runGitCommand(args: [String], in directory: URL) async throws -> String {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.standardOutput = pipe
        process.standardError = pipe

        // 设置工作目录
        process.currentDirectoryURL = directory

        // 设置环境变量
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        env["LANG"] = "en_US.UTF-8"
        process.environment = env

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 {
            throw NSError(
                domain: "GitService",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: output.trimmingCharacters(in: .whitespacesAndNewlines)]
            )
        }

        return output
    }
}

// MARK: - Array Helper

extension Array {
    func filtering(_ predicate: (Element) -> Bool) -> [Element] {
        filter(predicate)
    }
}
