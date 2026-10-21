import Foundation
import ProviderAgentLoop
import ProviderMessage
import ProviderToolManager
import Testing
@testable import PluginMessageListStandard

/// 串行化「会占用主线程的墙钟测量」。
///
/// `InitialPositionGateBudgetTests` 里的预算语义用例会**故意占住主线程**
/// （`Thread.sleep`）来制造 MainActor 竞争；而 `InitialPositionGateTimingTests`
/// 的放行耗时断言对 MainActor 竞争极其敏感 —— 两者并发时，后者会读到被顶高
/// 的延迟，误报成「收敛不再立即放行」。
///
/// Swift Testing 的 `.serialized` 只在 suite 内部串行，无法隔离不同 suite，
/// 因此这里加一把显式门闩（与 `PluginAppUpdate` 的 `AppUpdateNotificationGate`
/// 同构）。
///
/// - Important: 参与墙钟测量的用例必须**成对**调用 `acquire()` / `release()`；
///   建议用 `defer { release() }` 保证异常路径也会释放。
@MainActor
enum MainActorTimingGate {
    private static var isHeld = false
    private static var waiters: [CheckedContinuation<Void, Never>] = []

    /// 获取门闩。调用方必须配对调用 `release()`。
    static func acquire() async {
        if !isHeld {
            isHeld = true
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    /// 释放门闩，交给下一个等待者。
    static func release() {
        if waiters.isEmpty {
            isHeld = false
        } else {
            waiters.removeFirst().resume()
        }
    }
}

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
