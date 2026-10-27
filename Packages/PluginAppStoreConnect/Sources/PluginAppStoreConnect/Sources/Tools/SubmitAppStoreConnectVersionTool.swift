import Foundation
import KernelCore
import KitAgentTool

public struct SubmitAppStoreConnectVersionTool: SuperAgentTool {
    public let name = "app_store_connect_submit_version"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        AppStoreConnectLocalization.string("Submit an App Store version to App Review. The version must have an assigned build and complete metadata/screenshots.")
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        AppStoreConnectLocalization.string("Submit for Review")
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        AppStoreConnectToolSchemaValue.object([
            "type": .string("object"),
            "properties": .object([
                "versionID": .object([
                    "type": .string("string"),
                    "description": .string(AppStoreConnectLocalization.string("The App Store Connect appStoreVersion id to submit."))
                ])
            ]),
            "required": .array([.string("versionID")])
        ]).dictionaryValue
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .high
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        try await run(arguments: arguments, timeline: nil).content
    }

    /// 无会话上下文的结构化执行入口。
    ///
    /// 拿不到会话信息时不插入时间线消息 —— 避免把消息写进一个
    /// 不存在的会话里。
    public func executeResult(arguments: [String: ToolArgument]) async throws -> ToolCallResult {
        try await run(arguments: arguments, timeline: nil)
    }

    /// 带会话上下文的结构化执行入口。
    ///
    /// 借 `ToolExecutionContext` 拿到会话与回合 ID，在提交前 / 提交后
    /// 各插入一条结构化时间线消息，让用户明确「当前将提交什么」。
    /// 时间线消息只用于界面展示，不会回流到 LLM 上下文。
    public func executeResult(
        context: ToolExecutionContext,
        arguments: [String: ToolArgument]
    ) async throws -> ToolCallResult {
        try await run(
            arguments: arguments,
            timeline: ASCSubmissionTimelineContext(
                conversationID: context.conversationID,
                turnID: context.turnID
            )
        )
    }

    // MARK: - Core

    /// 提交审核的核心流程。
    ///
    /// - Parameters:
    ///   - arguments: 工具参数。
    ///   - timeline: 会话上下文；为 nil 时不产生时间线消息。
    /// - Returns: 工具结果。
    private func run(
        arguments: [String: ToolArgument],
        timeline: ASCSubmissionTimelineContext?
    ) async throws -> ToolCallResult {
        guard let versionID = arguments["versionID"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !versionID.isEmpty else {
            return ToolCallResult(content: "Missing or empty versionID.", isError: true)
        }

        let (client, errorMessage) = AppStoreConnectToolSupport.makeClient()
        guard let client else {
            let message = errorMessage ?? "Failed to initialize App Store Connect client."
            return ToolCallResult(content: message, isError: true)
        }

        do {
            // 前置检查 1：必须先关联 build
            guard let assignedBuildID = try await client.readAssignedBuildID(versionID: versionID) else {
                return ToolCallResult(
                    content: "Cannot submit: no build is assigned to version id=\(versionID). Use assign-build first.",
                    isError: true
                )
            }
            // 前置检查 2：不能重复提交
            if try await client.readSubmissionID(versionID: versionID) != nil {
                return ToolCallResult(
                    content: "Cannot submit: version id=\(versionID) already has a pending submission.",
                    isError: true
                )
            }

            // 提交前快照：明确「即将提交什么」，并列出还差什么。
            var preview = await ASCSubmissionSnapshotBuilder.build(
                client: client,
                versionID: versionID,
                assignedBuildID: assignedBuildID,
                stage: .preview
            )
            await insertTimelineMessage(timeline: timeline, preview: preview)

            // 存在阻塞性风险时中止提交，把问题交回给 LLM 与用户。
            if !preview.warnings.isEmpty {
                let warningText = preview.warnings.map { "- \($0)" }.joined(separator: "\n")
                let content = """
                Cannot submit: version id=\(versionID) may be missing required configuration.
                Warnings:
                \(warningText)
                Fix the issues above and try again.
                """
                preview.stage = .failed
                preview.errorMessage = content
                await insertTimelineMessage(timeline: timeline, preview: preview)
                return ToolCallResult(content: content, isError: true)
            }

            do {
                let submissionID = try await client.submitForReview(versionID: versionID)
                preview.stage = .submitted
                preview.submissionID = submissionID
                await insertTimelineMessage(timeline: timeline, preview: preview)
                return ToolCallResult(
                    content: "Version id=\(versionID) submitted for review. submission id=\(submissionID)"
                )
            } catch {
                preview.stage = .failed
                preview.errorMessage = error.localizedDescription
                await insertTimelineMessage(timeline: timeline, preview: preview)
                throw error
            }
        } catch {
            return ToolCallResult(
                content: "Failed to submit version: \(error.localizedDescription)",
                isError: true
            )
        }
    }

    /// 插入一条提交审核时间线消息。
    ///
    /// 消息管理器是主线程隔离的，因此这里切到 MainActor 插入，
    /// 保证「提交前 / 提交后」两条消息按调用顺序落在时间线上。
    private func insertTimelineMessage(
        timeline: ASCSubmissionTimelineContext?,
        preview: ASCSubmissionPreview
    ) async {
        guard let timeline else { return }
        await MainActor.run {
            ASCSubmissionTimelineBridge.insert(
                conversationID: timeline.conversationID,
                turnID: timeline.turnID,
                preview: preview
            )
        }
    }
}
