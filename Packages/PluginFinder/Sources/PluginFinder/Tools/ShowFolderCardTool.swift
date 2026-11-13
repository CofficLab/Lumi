import Foundation
import KitAgentTool

/// 在聊天消息区显示一张「文件夹卡片」的工具。
///
/// LLM 调用本工具后：
/// 1. 工具把卡片载荷转成一条带 `renderKind = "finder-card"` 的时间线消息；
/// 2. 插件注册的渲染器把这条消息画成一张小卡片；
/// 3. 用户点击卡片上的按钮，插件在 Finder 中打开指定文件夹。
///
/// 工具本身**不**打开 Finder——打开与否由用户点击决定。
/// 这是刻意的分离：LLM 提议一个位置，用户决定是否真的跳过去。
public struct ShowFolderCardTool: SuperAgentTool, @unchecked Sendable {
    /// 工具名（唯一标识符，不翻译）。
    public static let toolName = "show_folder_card"

    public let name = Self.toolName

    /// 插入卡片消息的桥。由插件在 `onBoot` 时创建并注入。
    private let bridge: FinderMessageBridge

    public init(bridge: FinderMessageBridge) {
        self.bridge = bridge
    }

    public func description(for language: LanguagePreference) -> String {
        "Show a folder card in the chat. The card has a button that opens the folder in Finder. Use this when the user should be given a clickable way to reach a specific folder on disk."
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        guard let path = Self.path(from: arguments), !path.isEmpty else {
            return "显示文件夹卡片"
        }
        return "显示文件夹卡片：\(path)"
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "path": [
                    "type": "string",
                    "description": "Absolute path of the folder the card should open in Finder.",
                ],
                "title": [
                    "type": "string",
                    "description": "Optional card title. Defaults to the folder name.",
                ],
                "description": [
                    "type": "string",
                    "description": "Optional card subtitle explaining what the folder contains.",
                ],
            ],
            "required": ["path"],
        ]
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    /// 无会话上下文的执行入口。
    ///
    /// 拿不到会话信息时不插入时间线消息——避免把消息写进一个不存在的会话里。
    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        try await run(arguments: arguments, timeline: nil).content
    }

    public func executeResult(arguments: [String: ToolArgument]) async throws -> ToolCallResult {
        try await run(arguments: arguments, timeline: nil)
    }

    /// 带会话上下文的结构化执行入口。
    ///
    /// 借 `ToolExecutionContext` 拿到会话与回合 ID，插入一条结构化时间线消息，
    /// 让用户拿到一个可点击的入口。
    /// 时间线消息只用于界面展示，不会回流到 LLM 上下文。
    public func executeResult(
        context: ToolExecutionContext,
        arguments: [String: ToolArgument]
    ) async throws -> ToolCallResult {
        try await run(
            arguments: arguments,
            timeline: FinderTimelineContext(
                conversationID: context.conversationID,
                turnID: context.turnID
            )
        )
    }

    // MARK: - Core

    /// 工具的核心流程。
    ///
    /// - Parameters:
    ///   - arguments: 工具参数。
    ///   - timeline: 会话上下文；为 nil 时不产生时间线消息。
    /// - Returns: 工具结果。
    private func run(
        arguments: [String: ToolArgument],
        timeline: FinderTimelineContext?
    ) async throws -> ToolCallResult {
        guard let path = Self.path(from: arguments), !path.isEmpty else {
            return ToolCallResult(
                content: "Missing or empty path. Provide the absolute path of the folder to show.",
                isError: true
            )
        }

        // 卡片按钮的语义是「打开文件夹」：目标必须真实存在且是目录。
        // 校验前置到插入卡片之前，避免先报成功、再产出一张点不开的废卡（#478）。
        let isExistingDirectory = await MainActor.run { FinderOpener.validatedURL(for: path) != nil }
        guard isExistingDirectory else {
            return ToolCallResult(
                content: "Path is not an existing directory: \(path). Provide the absolute path of a folder that exists.",
                isError: true
            )
        }

        let payload = FinderCardPayload(
            title: Self.string(from: arguments, key: "title") ?? "",
            description: Self.string(from: arguments, key: "description") ?? "",
            path: path
        )

        if let timeline {
            await MainActor.run {
                bridge.insert(
                    conversationID: timeline.conversationID,
                    turnID: timeline.turnID,
                    payload: payload
                )
            }
        }

        return ToolCallResult(
            content: "Folder card shown for \(path). The user can open it in Finder from the chat."
        )
    }

    // MARK: - Arguments

    /// 读取 `path` 参数并去掉首尾空白。
    static func path(from arguments: [String: ToolArgument]) -> String? {
        guard let raw = string(from: arguments, key: "path") else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// 读取一个字符串参数并去掉首尾空白。
    ///
    /// 参数缺失或为空白时返回 nil，让调用方决定回退策略。
    static func string(from arguments: [String: ToolArgument], key: String) -> String? {
        guard let value = arguments[key]?.value as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

/// Finder 卡片时间线消息的会话上下文。
///
/// 工具只有在拿到真实会话信息时才插入时间线消息；拿不到就不插入，
/// 避免把消息写进一个不存在的会话。
struct FinderTimelineContext: Sendable {
    let conversationID: UUID
    let turnID: UUID?

    init(conversationID: UUID, turnID: UUID?) {
        self.conversationID = conversationID
        self.turnID = turnID
    }
}
