import Foundation
import KitAgentTool
import LumiLoggingKit
import os

/// 把 LLM 在运行过程中发现的 Lumi 自身问题提交成 GitHub issue。
///
/// 设计要点：
/// - 目标仓库**固定为 `CofficLab/Lumi`**（Lumi 自己的 GitHub 仓库），
///   因为本工具的目的是让 LLM 把发现的 Lumi bug 反馈给维护者。
/// - 依赖本地 `gh` CLI：认证由 `gh` 自身管理，插件不碰 token / Keychain。
/// - `execute` 入口先做可用性检查（`which gh` + `gh auth status`），任一失败就
///   **直接放弃提交并抛出清晰错误**——避免把失败伪装成「issue 已创建」。
/// - issue body 自动追加 Lumi / macOS 环境诊断信息，便于维护者复现。
/// - 风险等级 `.medium`：访问网络并向外部仓库创建内容，属于跨边界写操作，
///   但不修改本地文件。
public struct CreateGitHubIssueTool: SuperAgentTool, @unchecked Sendable {
    public static let toolName = "github_create_issue"
    public let name = Self.toolName

    /// Lumi 自身的 GitHub 仓库。issue 统一提交到这里。
    public static let defaultRepository = "CofficLab/Lumi"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        """
        Submit an issue to Lumi's own GitHub repository (\(Self.defaultRepository)) \
        via the local `gh` CLI. Use this when you discover a problem in the Lumi \
        application itself while helping the user — for example a tool that returned \
        wrong results, a UI glitch, a crash, a misleading error message, or any \
        reproducible defect in Lumi's behavior. \
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
                    "description": "Short, descriptive issue title **in English**. Summarize the symptom in Lumi, not the cause.",
                ],
                "body": [
                    "type": "string",
                    "description": """
                    Issue body in Markdown, **written in English**. Include: what the user \
                    was trying to do, what Lumi did wrong, what you expected to happen, any \
                    relevant error output or tool call details. \
                    The tool will automatically append environment diagnostics (Lumi version, \
                    macOS version, architecture) — do not duplicate them. \
                    The tool REJECTS non-English text: if the content you pass contains \
                    Chinese/Japanese/Korean characters, it will fail and you must rewrite \
                    it in English before resubmitting.
                    """,
                ],
                "labels": [
                    "type": "array",
                    "items": ["type": "string"],
                    "description": "Optional labels to apply. Use labels that exist in the \(Self.defaultRepository) repo (e.g. `bug`).",
                ],
            ],
            "required": ["title", "body"],
            "additionalProperties": false,
        ]
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .medium
    }

    /// 以用户 GitHub 身份向公开仓库发布内容，必须由用户确认本次标题与正文。
    ///
    /// 风险等级无法表达"内容需要人工审阅"：`.medium` 在 Build 模式会自动批准。
    /// 因此每次调用都声明强制审批，避免模型或被注入的文本未经审阅公开发布。
    public func requiresExplicitApproval(arguments: [String: ToolArgument]) -> Bool {
        true
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        guard let title = arguments.stringValue("title") else { return "提交 Lumi issue" }
        let preview = title.count > 40 ? String(title.prefix(40)) + "…" : title
        return "提交 Lumi issue：\(preview)"
    }

    /// 带上下文的执行入口。
    public func executeResult(
        context: ToolExecutionContext,
        arguments: [String: ToolArgument]
    ) async throws -> ToolCallResult {
        return ToolCallResult(content: try await run(context: context, arguments: arguments))
    }

    // MARK: - 内部

    private func run(
        context: ToolExecutionContext,
        arguments: [String: ToolArgument]
    ) async throws -> String {
        try ensureActive(context)

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

        // 1. 强制英文校验：Lumi 的 issue 面向全球维护者，必须是英文。
        //    这是纯本地检查，无副作用，故放在最前——非英文内容必然不会进入 GitHub。
        let offenders = Self.nonEnglishOffenders(title: title, body: body)
        if !offenders.isEmpty {
            throw ToolExecutionError.executionFailed(
                toolName: name,
                reason: """
                Rejected: issue content must be written in English.

                Non-Latin characters detected in: \(offenders.joined(separator: ", ")).

                Lumi issues are read by maintainers worldwide, so the tool refuses to \
                submit non-English content. Rewrite the affected text in English and \
                call the tool again. If the non-Latin text comes from a log excerpt or \
                an error message, keep the original inside a code block and describe \
                it in English.
                """
            )
        }

        // 2. 定位 gh
        guard let ghPath = await GitHubCLI.locate() else {
            throw ToolExecutionError.executionFailed(
                toolName: name,
                reason: """
                Cannot submit Lumi issue: the `gh` CLI is not installed or not on PATH. \
                Ask the user to run `brew install gh` and then `gh auth login`. \
                The submission was abandoned.
                """
            )
        }

        // 3. 检查认证
        try ensureActive(context)
        guard await GitHubCLI.isAuthenticated(ghPath: ghPath) else {
            throw ToolExecutionError.executionFailed(
                toolName: name,
                reason: """
                Cannot submit Lumi issue: `gh auth status` failed, so `gh` is not logged in. \
                Ask the user to run `gh auth login` in a terminal. \
                The submission was abandoned.
                """
            )
        }

        // 4. 解析可选参数
        let labels = Self.extractStrings(arguments["labels"]?.value)

        // 5. 拼接完整 body：LLM 提供的内容 + 自动诊断信息。
        let fullBody = Self.renderedBody(userBody: body)

        // 6. 创建（目标仓库固定）
        try ensureActive(context)
        let result = await GitHubCLI.createIssue(
            ghPath: ghPath,
            workingDirectory: nil,
            title: title,
            body: fullBody,
            labels: labels,
            repository: Self.defaultRepository
        )

        if result.wasCancelled {
            throw CancellationError()
        }

        if result.wasTimedOut {
            throw ToolExecutionError.executionFailed(
                toolName: name,
                reason: """
                `gh issue create` timed out after \(Int(GitHubCLI.createTimeout))s and the \
                process was terminated. The issue may or may not have been created; check \
                \(Self.defaultRepository) before retrying.
                """
            )
        }

        guard result.isSuccess, !result.issueURL.isEmpty else {
            throw ToolExecutionError.executionFailed(
                toolName: name,
                reason: """
                `gh issue create` failed (exit=\(result.exitCode)).

                stdout:
                \(result.stdout)

                stderr:
                \(result.stderr)

                The submission was abandoned. Please report this error to the user.
                """
            )
        }

        return """
        ✅ Lumi issue submitted to \(Self.defaultRepository): \(result.issueURL)

        - Labels: \(labels.isEmpty ? "none" : labels.joined(separator: ", "))
        - Lumi/macOS environment diagnostics were appended automatically
        """
    }

    // MARK: - body 渲染

    /// 在 LLM 提供的 body 末尾追加环境诊断信息。
    ///
    /// 这样维护者能直接看到 Lumi 版本、macOS 版本、架构，无需再问用户。
    ///
    /// - Important: 诊断表本身也必须是英文——它会随 issue 一起提交到 GitHub。
    private static func renderedBody(userBody: String) -> String {
        let diagnostics = Diagnostics.current()
        return """
        \(userBody)

        ---

        _Automatically attached by Lumi `github_create_issue` tool._

        | Environment | Value |
        |---|---|
        | Lumi version | \(diagnostics.lumiVersion) |
        | Lumi build | \(diagnostics.lumiBuild) |
        | macOS | \(diagnostics.macOSVersion) |
        | Architecture | \(diagnostics.architecture) |
        | Preferred language | \(diagnostics.preferredLanguage) |
        """
    }

    // MARK: - 辅助

    /// 在每个可取消的等待前后确认调用方仍在等待，避免被停止的任务继续发布。
    private func ensureActive(_ context: ToolExecutionContext) throws {
        if Task.isCancelled || context.isCancelled() {
            throw CancellationError()
        }
    }

    /// 校验 title / body 是否为英文。返回非空的违规字段列表。
    ///
    /// Lumi 的 issue 面向全球维护者，中文 issue 对他们不可用。判据见
    /// ``EnglishLanguageGuard``：绝对字符数与占比任一超限即判为非英文，
    /// 避免把中文拆到两个字段后各自低于阈值而绕过。
    private static func nonEnglishOffenders(title: String, body: String) -> [String] {
        var offenders: [String] = []
        if EnglishLanguageGuard.containsNonEnglishContent(title) {
            offenders.append("`title` (\(EnglishLanguageGuard.nonLatinCharacterCount(in: title)) non-Latin characters)")
        }
        if EnglishLanguageGuard.containsNonEnglishContent(body) {
            offenders.append("`body` (\(EnglishLanguageGuard.nonLatinCharacterCount(in: body)) non-Latin characters)")
        }
        return offenders
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

// MARK: - 环境诊断

private struct Diagnostics {
    let lumiVersion: String
    let lumiBuild: String
    let macOSVersion: String
    let architecture: String
    let preferredLanguage: String

    static func current() -> Diagnostics {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = (info["CFBundleShortVersionString"] as? String) ?? "unknown"
        let build = (info["CFBundleVersion"] as? String) ?? "unknown"
        let os = ProcessInfo.processInfo.operatingSystemVersion
        let osString = "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
        #if arch(arm64)
        let arch = "arm64 (Apple Silicon)"
        #elseif arch(x86_64)
        let arch = "x86_64 (Intel)"
        #else
        let arch = "unknown"
        #endif
        let locale = Locale.preferredLanguages.first ?? "unknown"
        return Diagnostics(
            lumiVersion: version,
            lumiBuild: build,
            macOSVersion: osString,
            architecture: arch,
            preferredLanguage: locale
        )
    }
}

// MARK: - 参数访问（与 PluginToolManager/Tools/ArgumentAccess 同模式，避免跨包依赖）

extension [String: ToolArgument] {
    fileprivate func stringValue(_ key: String) -> String? {
        guard let value = self[key]?.value else { return nil }
        return value as? String
    }
}

// MARK: - 测试辅助

extension CreateGitHubIssueTool {
    /// 暴露 body 渲染，供测试断言「渲染结果不含非拉丁字符」。
    static func renderedBodyForTesting(userBody: String) -> String {
        renderedBody(userBody: userBody)
    }

    /// 暴露英文校验，供测试断言。
    static func nonEnglishOffendersForTesting(title: String, body: String) -> [String] {
        nonEnglishOffenders(title: title, body: body)
    }
}
