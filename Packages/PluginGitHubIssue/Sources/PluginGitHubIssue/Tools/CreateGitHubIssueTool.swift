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
///   **直接放弃提交**并返回清晰错误文本给 LLM——避免把失败伪装成「issue 已创建」。
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
        _ = context
        return ToolCallResult(content: try await run(arguments: arguments))
    }

    // MARK: - 内部

    private func run(arguments: [String: ToolArgument]) async throws -> String {
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
        let languageViolation = Self.englishViolation(title: title, body: body)
        if let languageViolation {
            return languageViolation
        }

        // 2. 定位 gh
        guard let ghPath = await GitHubCLI.locate() else {
            return Self.unavailableMessage(
                reason: "the `gh` CLI is not installed or not on PATH. Ask the user to run `brew install gh` and then `gh auth login`."
            )
        }

        // 3. 检查认证
        guard await GitHubCLI.isAuthenticated(ghPath: ghPath) else {
            return Self.unavailableMessage(
                reason: "`gh auth status` failed, so `gh` is not logged in. Ask the user to run `gh auth login` in a terminal."
            )
        }

        // 4. 解析可选参数
        let labels = Self.extractStrings(arguments["labels"]?.value)

        // 5. 拼接完整 body：LLM 提供的内容 + 自动诊断信息。
        let fullBody = Self.renderedBody(userBody: body)

        // 6. 创建（目标仓库固定）
        let result = await GitHubCLI.createIssue(
            ghPath: ghPath,
            workingDirectory: nil,
            title: title,
            body: fullBody,
            labels: labels,
            repository: Self.defaultRepository
        )

        guard result.isSuccess, !result.issueURL.isEmpty else {
            return Self.failureMessage(
                exitCode: result.exitCode,
                stdout: result.stdout,
                stderr: result.stderr
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

    /// 校验 title / body 是否为英文。返回非 nil 表示违反英文要求，附带说明。
    ///
    /// Lumi 的 issue 面向全球维护者，中文 issue 对他们不可用。判据见
    /// ``EnglishLanguageGuard``：统计 CJK 字形数量，超过阈值即判为非英文。
    ///
    /// - Note: 错误提示本身用英文写——LLM 需要读懂它才知道怎么改写。
    private static func englishViolation(title: String, body: String) -> String? {
        let titleCount = EnglishLanguageGuard.nonLatinCharacterCount(in: title)
        let bodyCount = EnglishLanguageGuard.nonLatinCharacterCount(in: body)

        var offenders: [String] = []
        if titleCount >= EnglishLanguageGuard.minimumNonLatinCount {
            offenders.append("`title` (\(titleCount) non-Latin characters)")
        }
        if bodyCount >= EnglishLanguageGuard.minimumNonLatinCount {
            offenders.append("`body` (\(bodyCount) non-Latin characters)")
        }
        guard !offenders.isEmpty else { return nil }

        return """
        ❌ Rejected: issue content must be written in English.

        Non-Latin characters detected in: \(offenders.joined(separator: ", ")).

        Lumi issues are read by maintainers worldwide, so the tool refuses to \
        submit non-English content. Rewrite the affected text in English and \
        call the tool again. If the non-Latin text comes from a log excerpt or \
        an error message, keep the original inside a code block and describe \
        it in English.
        """
    }

    /// 不可用场景统一格式：LLM 看到这个文本就知道放弃提交。
    ///
    /// - Important: 提示文本保持英文，与 issue 语言要求一致；
    ///   LLM 需要读懂它才知道该怎么向用户解释。
    private static func unavailableMessage(reason: String) -> String {
        "⚠️ Cannot submit Lumi issue: \(reason) The submission was abandoned."
    }

    /// gh 创建失败：把原始输出原样交给 LLM，便于二次诊断。
    private static func failureMessage(exitCode: Int32, stdout: String, stderr: String) -> String {
        """
        ❌ `gh issue create` failed (exit=\(exitCode)).

        stdout:
        \(stdout)

        stderr:
        \(stderr)

        The submission was abandoned. Please report this error to the user.
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
    static func englishViolationForTesting(title: String, body: String) -> String? {
        englishViolation(title: title, body: body)
    }
}
