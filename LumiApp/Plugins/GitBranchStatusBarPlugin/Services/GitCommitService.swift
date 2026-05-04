import Foundation
import LibGit2Swift
import MagicKit

/// Git Commit 服务
///
/// 负责使用大模型生成 commit message 并直接执行 commit 操作。
/// 使用非流式 HTTP 请求，无需 SSE。
enum GitCommitService: SuperLog {
    nonisolated static let emoji = "📝"
    nonisolated static let verbose = false

    /// Commit 语言偏好
    enum Language {
        case english
        case chinese

        var instruction: String {
            switch self {
            case .english:
                return "Use English. Follow conventional commits format (feat/fix/docs/refactor/chore etc.). Keep it concise."
            case .chinese:
                return "Use Chinese. Follow conventional commits format (feat/fix/docs/refactor/chore etc.). Keep it concise."
            }
        }
    }

    /// 生成的 Commit 结果
    struct Result {
        let message: String
        let commitHash: String
    }

    /// 获取当前未提交的变更摘要
    /// - Parameter path: 项目路径
    /// - Returns: 变更摘要文本（status + diff）
    static func gatherChanges(at path: String) async throws -> String {
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
    /// - Parameters:
    ///   - changes: 变更摘要
    ///   - language: 语言偏好
    ///   - llmService: LLM 服务
    ///   - config: LLM 配置
    /// - Returns: 生成的 commit message
    static func generateCommitMessage(
        changes: String,
        language: Language,
        llmService: LLMService,
        config: LLMConfig
    ) async throws -> String {
        let systemPrompt = """
        You are an expert developer reviewing code changes. Generate a concise, descriptive commit message.

        Requirements:
        1. \(language.instruction)
        2. Use conventional commits format: <type>(<scope>): <description>
        3. Common types: feat, fix, docs, style, refactor, perf, test, chore, ci, build
        4. Keep the message under 72 characters for the title
        5. Optionally add a body paragraph for complex changes
        6. Return ONLY the commit message, nothing else, no explanations
        7. Do NOT wrap in code blocks or quotes

        Respond with the commit message directly.
        """

        let userPrompt = """
        Here are the code changes:

        \(changes)

        Generate a commit message for these changes.
        """

        let tempConvId = UUID()
        let messages = [
            ChatMessage(role: .system, conversationId: tempConvId, content: systemPrompt),
            ChatMessage(role: .user, conversationId: tempConvId, content: userPrompt)
        ]

        let response = try await llmService.sendMessage(messages: messages, config: config)

        let rawContent = response.content.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !rawContent.isEmpty else {
            throw GitCommitError.emptyResponse
        }

        // 清理可能的 markdown code block
        var cleaned = rawContent
        if cleaned.hasPrefix("```") {
            cleaned = cleaned.replacingOccurrences(of: "```", with: "").trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        }

        // 去除首尾空行
        let lines = cleaned.components(separatedBy: CharacterSet.newlines).filter { !$0.isEmpty }
        return lines.joined(separator: "\n")
    }

    /// 执行 git commit（通过命令行）
    /// - Parameters:
    ///   - message: commit message
    ///   - path: 项目路径
    /// - Returns: commit hash
    static func executeCommit(message: String, at path: String) throws -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", "cd \(path) && git add -A && git commit -m '\(message.replacingOccurrences(of: "'", with: "\\'"))' 2>&1 && git rev-parse --short HEAD"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        try task.run()
        task.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        guard task.terminationStatus == 0 else {
            throw GitCommitError.commitFailed(output)
        }

        // 最后一行是 commit hash
        let lines = output.components(separatedBy: CharacterSet.newlines).filter { !$0.isEmpty }
        guard let hash = lines.last, !hash.isEmpty else {
            throw GitCommitError.commitFailed("无法获取 commit hash")
        }

        return hash
    }
}

// MARK: - 错误类型

enum GitCommitError: LocalizedError {
    case notGitRepository
    case noChanges
    case emptyResponse
    case commitFailed(String)
    case llmError(String)

    var errorDescription: String? {
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
