import Foundation

public struct MessageTokenUsage: Sendable, Equatable {
    /// 已用当前日历归一化到当天 00:00 的日期。
    public let day: Date
    public let inputTokens: Int
    public let outputTokens: Int

    public init(day: Date, inputTokens: Int, outputTokens: Int) {
        self.day = day
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }

    public var totalTokens: Int {
        inputTokens + outputTokens
    }
}

/// 消息管理能力协议
///
/// 定义消息的获取、删除、插入等管理功能。
@MainActor
public protocol MessageManaging: ObservableObject {
    /// 获取指定对话的所有消息（原始数据,包含工具调用结果）
    ///
    /// 后端逻辑（如构建 LLM 上下文、生成摘要）应使用此方法,确保获得完整消息历史。
    func messages(for conversationID: UUID) -> [LumiChatMessage]

    /// 获取指定对话的 UI 展示消息（根据详细程度过滤）
    ///
    /// 低于「详细」(V3) 级别时,会过滤掉工具调用结果消息（role == .tool）。
    /// UI 层（如 MessageListView）应使用此方法,无需自行判断详细程度。
    func displayMessages(for conversationID: UUID) -> [LumiChatMessage]

    /// 获取指定对话的一页可见消息。
    ///
    /// - Parameters:
    ///   - limit: 最多返回多少条消息。
    ///   - beforeMessageID: 以该消息为边界，返回它之前的消息页；传 `nil` 时返回最近一页。
    func visibleMessages(for conversationID: UUID, limit: Int, beforeMessageID: UUID?) async -> [LumiChatMessage]

    /// 获取指定对话的消息数量。
    ///
    /// 列表、徽标等轻量 UI 应使用此方法，避免为了计数加载整段消息正文或附件。
    func messageCount(for conversationID: UUID) async -> Int

    /// 指定消息之前是否还有更早的消息。
    func hasEarlierMessages(for conversationID: UUID, beforeMessageID: UUID?) async -> Bool

    /// 删除指定消息
    func deleteMessage(id: UUID, in conversationID: UUID)

    /// 插入新消息到指定对话
    func insertMessage(_ message: LumiChatMessage, to conversationID: UUID)

    /// 更新消息内容
    func updateMessage(id: UUID, in conversationID: UUID, content: String)

    /// 更新消息中的 tool call 结果
    ///
    /// 在 tool call 执行完成后，需要更新 assistant 消息中对应 toolCall 的 result 字段，
    /// 以便 UI 能够显示正确的视觉状态（成功/失败/执行时长）。
    func updateToolCallResult(
        _ result: LumiToolResult,
        toolCallID: String,
        assistantMessageID: UUID,
        in conversationID: UUID
    )

    /// 清空指定对话的所有消息
    func clearMessages(in conversationID: UUID)

    /// 获取指定消息
    func message(id: UUID, in conversationID: UUID) -> LumiChatMessage?

    /// 获取指定对话的最后一个消息
    func lastMessage(in conversationID: UUID) -> LumiChatMessage?

    /// 获取自指定日期以来每日的消息数量（跨所有对话）
    ///
    /// 用于活动热力图等统计功能。返回的字典键为每日 00:00 的日期。
    func fetchDailyMessageCounts(since: Date) async -> [Date: Int]

    /// 获取自指定日期以来每日的 token 消耗总量（跨所有对话）
    ///
    /// 用于 token 用量图表。返回的字典键为每日 00:00 的日期。
    /// Token 数量为 inputTokenCount + outputTokenCount 之和。
    func fetchDailyTokenCounts(since: Date) async -> [Date: Int]

    /// 获取某一天的 token 消耗量（跨所有对话）。
    ///
    /// - Parameters:
    ///   - day: 需要查询的日期，会按当前日历归一化到当天 00:00。
    ///   - providerID: 可选供应商 ID 过滤。
    ///   - modelName: 可选模型名称过滤。
    /// - Returns: input/output token 拆分及总量。
    func fetchTokenUsage(on day: Date, providerID: String?, modelName: String?) async -> MessageTokenUsage
}

public extension MessageManaging {
    func fetchTokenUsage(on day: Date) async -> MessageTokenUsage {
        await fetchTokenUsage(on: day, providerID: nil, modelName: nil)
    }
}
