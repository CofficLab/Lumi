import Foundation
import ProviderAgentLoop
import ProviderMessage
import ProviderToolManager
import Testing
@testable import PluginMessageListStandard

/// 跨测试文件共享的消息工厂。
func makeMessage(
    id: UUID = UUID(),
    conversationID: UUID,
    role: MessageRole,
    content: String,
    createdAt: Date = Date(),
    turnID: UUID? = nil,
    isError: Bool = false,
    toolCalls: [MessageToolCall]? = nil
) -> Message {
    Message(
        id: id,
        conversationID: conversationID,
        role: role,
        content: content,
        createdAt: createdAt,
        turnID: turnID,
        isError: isError,
        toolCalls: toolCalls
    )
}

/// 跨测试文件共享的工具调用记录工厂。
func makeToolCallRecord(
    id: String,
    conversationID: UUID,
    startedAt: Date = Date(timeIntervalSince1970: 0),
    completed: Bool = false,
    duration: TimeInterval? = nil,
    isError: Bool = false
) -> ToolCallRecord {
    ToolCallRecord(
        id: id,
        toolCallID: "call-\(id)",
        toolName: "tool_\(id)",
        toolDisplayName: "Tool \(id)",
        turnID: nil,
        conversationID: conversationID,
        createdAt: startedAt,
        startedAt: startedAt,
        completedAt: completed ? startedAt.addingTimeInterval(duration ?? 1) : nil,
        duration: duration,
        argumentsJSON: "{}",
        resultContent: "result",
        resultJSON: nil,
        resultIsError: isError,
        riskLevel: "low"
    )
}

/// 可编程的分页消息能力替身。
///
/// `earlierPage` 用于模拟游标分页（向上翻页）：当请求带 `beforeMessageID` 时
/// 返回更早一页，否则返回最近一页 `page`。
@MainActor
final class StubMessageListMessageCapability: MessageListMessageCapability {
    var page: [Message]
    var earlierPage: [Message]?
    let hasEarlier: Bool
    private(set) var pageRequests: [(limit: Int, beforeMessageID: UUID?, includesToolMessages: Bool)] = []
    private(set) var earlierRequests: [(beforeMessageID: UUID?, includesToolMessages: Bool)] = []

    init(page: [Message], hasEarlier: Bool = false, earlierPage: [Message]? = nil) {
        self.page = page
        self.hasEarlier = hasEarlier
        self.earlierPage = earlierPage
    }

    func messagesSnapshot(in conversationID: UUID) async -> [Message] { page }

    func messagePageAsync(
        for conversationID: UUID,
        limit: Int,
        beforeMessageID: UUID?,
        includesToolMessages: Bool
    ) async -> [Message] {
        pageRequests.append((limit, beforeMessageID, includesToolMessages))
        if beforeMessageID != nil, let earlierPage { return earlierPage }
        return page
    }

    func hasEarlierMessagesAsync(
        for conversationID: UUID,
        beforeMessageID: UUID?,
        includesToolMessages: Bool
    ) async -> Bool {
        earlierRequests.append((beforeMessageID, includesToolMessages))
        return hasEarlier
    }
}
