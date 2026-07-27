import Foundation
import LumiKernel
import SuperLogKit
import LibGit2Swift
import ShellKit

/// Git Commit 服务
///
/// 负责使用大模型生成 commit message 并直接执行 commit 操作。
/// 使用非流式 HTTP 请求，无需 SSE。
public enum GitCommitService: SuperLog {
    public nonisolated static let emoji = "📝"
    public nonisolated static let verbose: Bool = true

    /// Commit 语言偏好
    public enum Language {
        case english
        case chinese

        public var instruction: String {
            switch self {
            case .english:
                return "Use English. Follow conventional commits format (feat/fix/docs/refactor/chore etc.). Keep it concise."
            case .chinese:
                return "Use Chinese. Follow conventional commits format (feat/fix/docs/refactor/chore etc.). Keep it concise."
            }
        }
    }

    /// 生成的 Commit 结果
    public struct Result {
        public let message: String
        public let commitHash: String
    }

    /// 获取当前未提交的变更摘要
    /// - Parameter path: 项目路径
    /// - Returns: 变更摘要文本（status + diff）
    public static func gatherChanges(at path: String) async throws -> String {
        var output = ""

        // 1. 文件列表摘要
        let unstagedFiles = try LibGit2.getDiffFileList(at: path, staged: false)
        let stagedFiles = try LibGit2.getDiffFileList(at: path, staged: true)

        let hasStaged = !stagedFiles.isEmpty
        let hasUnstaged = !unstagedFiles.isEmpty

        if hasStaged || hasUnstaged {
            output += "## Changes\n\n"

            if hasStaged {
                output += "### Staged files:\n"
                for f in stagedFiles {
                    output += "- \(f.file) (\(f.changeType))\n"
                }
                output += "\n"
            }

            if hasUnstaged {
                output += "### Unstaged files:\n"
                for f in unstagedFiles {
                    output += "- \(f.file) (\(f.changeType))\n"
                }
                output += "\n"
            }
        } else {
            throw GitCommitError.noChanges
        }

        // 2. diff 内容
        let allFiles = Set(stagedFiles.map(\.file) + unstagedFiles.map(\.file))
        var diffContent = ""
        for file in allFiles {
            do {
                let fileDiff = try LibGit2.getFileDiff(for: file, at: path, staged: false)
                if !fileDiff.isEmpty {
                    diffContent += fileDiff + "\n"
                }
            } catch {
                // 某些文件可能没有 diff（如新文件未 staged），忽略
            }
        }

        // 也获取 staged 的 diff
        for file in stagedFiles {
            do {
                let fileDiff = try LibGit2.getFileDiff(for: file.file, at: path, staged: true)
                if !fileDiff.isEmpty && !diffContent.contains(file.file) {
                    diffContent += fileDiff + "\n"
                }
            } catch {
                // 忽略
            }
        }

        if !diffContent.isEmpty {
            // 限制 diff 长度，避免超出 token 限制
            let maxDiffChars = 30_000
            if diffContent.count > maxDiffChars {
                diffContent = String(diffContent.prefix(maxDiffChars))
                output += "## Diff (truncated)\n\n```\n\(diffContent)\n```"
            } else {
                output += "## Diff\n\n```\n\(diffContent)\n```"
            }
        }

        return output
    }

    /// 生成 commit message
    ///
    /// 该方法只关心"调用一次 LLM 并取回结果",因此通过最小协议
    /// `LumiEphemeralChatQuerying` 与 chat 子系统通信 —— 不必依赖
    /// `LumiChatServicing` 的全套方法。这让 GitPlugin 与大协议解耦,
    /// 便于将来其他实现只提供该子集也能被 GitPlugin 复用。
    @MainActor
    public static func generateCommitMessage(
        changes: String,
        language: Language,
        chatService: any LumiEphemeralChatQuerying
    ) async throws -> String {
        let conversationID = chatService.selectedConversationID ?? UUID()
        guard let model = chatService.modelName(for: conversationID) ?? chatService.selectedModel else {
            throw GitCommitError.llmError("No model selected")
        }

        let prompt = """
        You are an expert developer reviewing code changes. Generate a concise, descriptive commit message.

        Requirements:
        1. \(language.instruction)
        2. Use conventional commits format: <type>(<scope>): <description>
        3. Common types: feat, fix, docs, style, refactor, perf, test, chore, ci, build
        4. Keep the message under 72 characters for the title
        5. Optionally add a body paragraph for complex changes
        6. Return ONLY the commit message, nothing else, no explanations
        7. Do NOT wrap in code blocks or quotes

        Here are the code changes:

        \(changes)

        Generate a commit message for these changes.
        """

        let response = try await chatService.generateEphemeralCompletion(
            messages: [
                LumiChatMessage(conversationID: conversationID, role: .user, content: prompt),
            ],
            model: model,
            conversationID: conversationID
        )

        let rawContent = response.content.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !rawContent.isEmpty else {
            throw GitCommitError.emptyResponse
        }

        var cleaned = rawContent
        if cleaned.hasPrefix("```") {
            cleaned = cleaned.replacingOccurrences(of: "```", with: "").trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        }

        let lines = cleaned.components(separatedBy: CharacterSet.newlines).filter { !$0.isEmpty }
        return lines.joined(separator: "\n")
    }

    /// 执行 git commit（通过命令行）
    /// - Parameters:
    ///   - message: commit message
    ///   - path: 项目路径
    /// - Returns: commit hash
    public static func executeCommit(message: String, at path: String) async throws -> String {
        try await runCommitProcess(message: message, at: path)
    }

    /// 在后台执行 git commit
    private nonisolated static func runCommitProcess(message: String, at path: String) async throws -> String {
        let result = try await Shell.execute(
            executable: "/usr/bin/env",
            arguments: ["git", "-C", path, "add", "-A"],
            options: ShellOptions(throwsOnError: false)
        )
        guard result.exitCode == 0 else {
            let output = result.stderr.isEmpty ? result.stdout : result.stderr
            throw GitCommitError.commitFailed(output)
        }

        let commit = try await Shell.execute(
            executable: "/usr/bin/env",
            arguments: ["git", "-C", path, "commit", "-m", message],
            options: ShellOptions(throwsOnError: false)
        )
        guard commit.exitCode == 0 else {
            let output = commit.stderr.isEmpty ? commit.stdout : commit.stderr
            throw GitCommitError.commitFailed(output)
        }

        let hashResult = try await Shell.execute(
            executable: "/usr/bin/env",
            arguments: ["git", "-C", path, "rev-parse", "--short", "HEAD"],
            options: ShellOptions(throwsOnError: false)
        )
        guard hashResult.exitCode == 0 else {
            let output = hashResult.stderr.isEmpty ? hashResult.stdout : hashResult.stderr
            throw GitCommitError.commitFailed(output)
        }

        // 最后一行是 commit hash
        let lines = hashResult.stdout.components(separatedBy: CharacterSet.newlines).filter { !$0.isEmpty }
        guard let hash = lines.last, !hash.isEmpty else {
            throw GitCommitError.commitFailed("无法获取 commit hash")
        }

        return hash
    }
}

// MARK: - 错误类型

public enum GitCommitError: LocalizedError {
    case notGitRepository
    case noChanges
    case emptyResponse
    case commitFailed(String)
    case llmError(String)

    public var errorDescription: String? {
        switch self {
        case .notGitRepository:
            return "Not a Git Repository"
        case .noChanges:
            return "No changes to commit"
        case .emptyResponse:
            return "AI returned empty response"
        case .commitFailed(let msg):
            return "Commit failed: \(msg)"
        case .llmError(let msg):
            return "LLM error: \(msg)"
        }
    }
}
