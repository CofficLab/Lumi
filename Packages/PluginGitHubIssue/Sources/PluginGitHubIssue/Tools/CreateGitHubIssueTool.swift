import Foundation
import KitAgentTool
import LumiLoggingKit
import os

/// 把 Agent 遇到的工具故障 / 问题提交成 GitHub issue。
///
/// 设计要点：
/// - 依赖本地 `gh` CLI：认证与仓库定位由 `gh` 自身管理，插件不碰 token / Keychain。
/// - `execute` 入口先做可用性检查（`which gh` + `gh auth status`），任一失败就
///   **直接放弃提交**并返回清晰错误文本给 LLM——避免把失败伪装成「issue 已创建」。
/// - 仓库优先由 `gh` 从对话绑定项目的 cwd git remote 推断；LLM 可用 `repository`
///   参数显式覆盖（`owner/repo`）。
/// - 风险等级 `.medium`：访问网络并向外部仓库创建内容，属于跨边界写操作，
///   但不修改本地文件。
public struct CreateGitHubIssueTool: SuperAgentTool, @unchecked Sendable {
    public static let toolName = "github_create_issue"
    public let name = Self.toolName

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        """
        Submit a GitHub issue via the local `gh` CLI. Use when you hit a tool bug, \
        an unexplained failure, or any reproducible problem worth tracking. \
        The tool will abort early (no network call, no issue created) if `gh` is \
        missing or not authenticated — in that case, tell the user to install or \
        log in to `gh` locally.
        """
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "title": [
                    "type": "string",
                    "description": "Short, descriptive issue title. Summarize the symptom, not the cause.",
                ],
                "body": [
                    "type": "string",
                    "description": "Issue body in Markdown. Include: which tool failed, inputs you passed, expected behavior, actual behavior, and any relevant error output. Append environment / diagnostics info when useful.",
                ],
                "labels": [
                    "type": "array",
                    "items": ["type": "string"],
                    "description": "Optional labels to apply. Use labels that exist in the target repo.",
                ],
                "repository": [
                    "type": "string",
                    "description": "Optional target repository in `owner/repo` form. Defaults to the repo inferred from the current project's git remote.",
                ],
            ],
            "required": ["title", "body"],
            "additionalProperties": false,
        ]
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .medium
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        guard let title = arguments.stringValue("title") else { return "提交 GitHub issue" }
        let preview = title.count > 40 ? String(title.prefix(40)) + "…" : title
        return "提交 GitHub issue：\(preview)"
    }

    /// 带上下文的执行入口：需要 `context` 拿到对话绑定的项目路径作为 gh 的 cwd。
    public func executeResult(
        context: ToolExecutionContext,
        arguments: [String: ToolArgument]
    ) async throws -> ToolCallResult {
        ToolCallResult(content: try await run(context: context, arguments: arguments))
    }

    // MARK: - 内部

    private func run(
        context: ToolExecutionContext,
        arguments: [String: ToolArgument]
    ) async throws -> String {
        guard let title = arguments.stringValue("title"),
              let body = arguments.stringValue("body"),
              !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw ToolExecutionError.executionFailed(
                toolName: name,
                reason: "`title` and `body` are required and must not be empty."
            )
        }

        // 1. 定位 gh
        guard let ghPath = await GitHubCLI.locate() else {
            return Self.unavailableMessage(
                reason: "`gh` CLI 未安装或不在 PATH 中。请先 `brew install gh` 并在终端 `gh auth login` 后重试。"
            )
        }

        // 2. 检查认证
        guard await GitHubCLI.isAuthenticated(ghPath: ghPath) else {
            return Self.unavailableMessage(
                reason: "`gh auth status` 失败——本地 gh 未登录。请在终端运行 `gh auth login` 后重试。"
            )
        }

        // 3. 解析可选参数
        let labels = Self.extractStrings(arguments["labels"]?.value)
        let repository = arguments.stringValue("repository")

        // 4. cwd = 对话绑定项目路径。gh 据此从 git remote 推断目标仓库。
        let cwd = await context.conversationProjectPath()

        // 5. 创建
        let result = await GitHubCLI.createIssue(
            ghPath: ghPath,
            workingDirectory: cwd,
            title: title,
            body: body,
            labels: labels,
            repository: repository
        )

        guard result.isSuccess, !result.issueURL.isEmpty else {
            return Self.failureMessage(
                exitCode: result.exitCode,
                stdout: result.stdout,
                stderr: result.stderr
            )
        }

        return """
        ✅ Issue 已创建：\(result.issueURL)

        - 仓库：\(repository ?? "（由 gh 从 cwd git remote 推断）")
        - 标签：\(labels.isEmpty ? "无" : labels.joined(separator: ", "))
        """
    }

    // MARK: - 辅助

    /// 不可用场景统一格式：LLM 看到这个文本就知道放弃提交。
    private static func unavailableMessage(reason: String) -> String {
        "⚠️ 无法提交 GitHub issue：\(reason) 已放弃本次提交。"
    }

    /// gh 创建失败：把原始输出原样交给 LLM，便于二次诊断。
    private static func failureMessage(exitCode: Int32, stdout: String, stderr: String) -> String {
        """
        ❌ `gh issue create` 失败（exit=\(exitCode)）。

        stdout:
        \(stdout)

        stderr:
        \(stderr)

        已放弃本次提交，请将错误信息反馈给用户。
        """
    }

    /// `arguments["labels"]?.value` 可能是 `[String]`、`[Any]` 或 JSON 数组字符串，
    /// 分别处理；非数组返回空。
    private static func extractStrings(_ value: Any?) -> [String] {
        guard let value else { return [] }
        if let strings = value as? [String] { return strings }
        if let anyArray = value as? [Any] {
            return anyArray.compactMap { $0 as? String }
        }
        if let string = value as? String,
           let data = string.data(using: .utf8),
           let decoded = try? JSONSerialization.jsonObject(with: data) as? [Any] {
            return decoded.compactMap { $0 as? String }
        }
        return []
    }
}

// MARK: - 参数访问（与 PluginToolManager/Tools/ArgumentAccess 同模式，避免跨包依赖）

extension [String: ToolArgument] {
    fileprivate func stringValue(_ key: String) -> String? {
        guard let value = self[key]?.value else { return nil }
        return value as? String
    }
}
