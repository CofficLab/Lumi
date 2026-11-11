import Foundation
import ProviderConversation
import ProviderConversationState
import ProviderMessage
import ProviderMessageRendering
import ProviderMessageStreaming
@testable import PluginMessageListChatGPT

// MARK: - 消息能力替身

/// 可控的消息能力替身：按 `beforeMessageID` 分页，并可用 gate 挂起读取。
@MainActor
final class StubMessageCapability: MessageListMessageCapability {
    /// 全部消息（按时间升序）。
    var messages: [Message] = []
    /// 挂起读取的闸门；为 nil 时读取立即返回。
    var gate: AsyncGate?
    /// 分页请求次数。
    private(set) var pageRequestCount = 0

    func messagePageAsync(
        for conversationID: UUID,
        limit: Int,
        beforeMessageID: UUID?,
        includesToolMessages: Bool
    ) async -> [Message] {
        pageRequestCount += 1
        if let gate {
            await gate.wait()
        }
        let ordered = messages
            .filter { $0.conversationID == conversationID }
            .sorted(by: stubMessageOrdering)
        let scoped = ordered.filter { message in
            guard !includesToolMessages else { return true }
            return message.role != .tool
        }
        guard let beforeMessageID else {
            return Array(scoped.suffix(limit))
        }
        guard let index = scoped.firstIndex(where: { $0.id == beforeMessageID }) else {
            return []
        }
        return Array(scoped[..<index].suffix(limit))
    }

    func hasEarlierMessagesAsync(
        for conversationID: UUID,
        beforeMessageID: UUID?,
        includesToolMessages: Bool
    ) async -> Bool {
        let ordered = messages
            .filter { $0.conversationID == conversationID }
            .sorted(by: stubMessageOrdering)
        let scoped = ordered.filter { message in
            guard !includesToolMessages else { return true }
            return message.role != .tool
        }
        guard let beforeMessageID,
              let index = scoped.firstIndex(where: { $0.id == beforeMessageID }) else {
            return false
        }
        return index > 0
    }
}

/// 替身专用的消息排序：先按 createdAt，再按 id 字符串。
func stubMessageOrdering(_ lhs: Message, _ rhs: Message) -> Bool {
    if lhs.createdAt == rhs.createdAt { return lhs.id.uuidString < rhs.id.uuidString }
    return lhs.createdAt < rhs.createdAt
}

/// 异步闸门：用于在测试里精确控制「读取何时返回」。
///
/// - Note: 禁止用任意 `sleep` 猜时序 —— 闸门让测试确定性地控制挂起与释放。
actor AsyncGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    /// 挂起所有等待者，直到 `open()` 被调用。
    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    /// 释放闸门并唤醒全部等待者。
    func open() {
        isOpen = true
        let pending = waiters
        waiters = []
        for continuation in pending {
            continuation.resume()
        }
    }
}

// MARK: - 会话能力替身

/// 可控的会话能力替身。
@MainActor
final class StubConversationCapability: MessageListConversationCapability {
    var selectedConversationID: UUID?
    /// 各会话的详细度。
    var verbosities: [UUID: ResponseVerbosity] = [:]
    /// 默认详细度。
    var defaultVerbosity: ResponseVerbosity = .chatGPT

    init(selectedConversationID: UUID? = nil) {
        self.selectedConversationID = selectedConversationID
    }

    func verbosity(for conversationID: UUID?) -> ResponseVerbosity {
        guard let conversationID else { return defaultVerbosity }
        return verbosities[conversationID] ?? defaultVerbosity
    }
}

// MARK: - 渲染能力替身

@MainActor
final class StubRenderingCapability: MessageListRenderingCapability {
    func renderer(for message: Message) -> MessageRendererItem? {
        nil
    }
}

// MARK: - 流式能力替身

@MainActor
final class StubStreamingCapability: MessageListStreamingCapability {
    var streamingMessageValue: Message?
    var stageValue: MessageStreamingStage = .idle
    /// 写入次数计数：用于断言「16ms 窗口内多次 delta 合并为一次刷新」。
    private(set) var writeCount = 0

    func streamingMessage(for conversationID: UUID) -> Message? {
        streamingMessageValue
    }

    func stage(for conversationID: UUID) -> MessageStreamingStage {
        stageValue
    }

    // MARK: - 写入侧（仅测试用）

    func start(conversationID: UUID) {
        writeCount += 1
        streamingMessageValue = Message(
            conversationID: conversationID,
            role: .assistant,
            content: ""
        )
        stageValue = .sending
    }

    func appendContent(_ content: String, conversationID: UUID) {
        writeCount += 1
        guard var row = streamingMessageValue else { return }
        row.content += content
        streamingMessageValue = row
        stageValue = .generating
    }

    func appendThinking(_ content: String, conversationID: UUID) {
        writeCount += 1
        guard var row = streamingMessageValue else { return }
        row.reasoningContent = (row.reasoningContent ?? "") + content
        streamingMessageValue = row
        stageValue = .thinking
    }

    func end(conversationID: UUID) {
        writeCount += 1
        streamingMessageValue = nil
        stageValue = .idle
    }
}

// MARK: - 会话状态能力替身

@MainActor
final class StubConversationStateCapability: MessageListConversationStateCapability {
    var snapshot: ConversationStateSnapshot = ConversationStateSnapshot(
        conversationID: UUID()
    )

    func state(for conversationID: UUID) -> ConversationStateSnapshot {
        snapshot
    }
}

// MARK: - 服务容器装配

/// 构造带全部替身的 `MessageListServices`。
@MainActor
func makeStubServices(
    conversationID: UUID?,
    messages: StubMessageCapability = StubMessageCapability(),
    conversations: StubConversationCapability = StubConversationCapability(),
    streaming: StubStreamingCapability = StubStreamingCapability(),
    conversationState: StubConversationStateCapability = StubConversationStateCapability(),
    resolveText: @escaping (String) -> String = { $0 }
) -> MessageListServices {
    // 参数顺序按「会话 → 消息 → 渲染 → 流式 → 状态」排列，
    // 调用点必须遵循该顺序（Swift 的实参标签顺序规则）。
    conversations.selectedConversationID = conversationID
    return MessageListServices(
        conversations: conversations,
        conversationState: conversationState,
        messages: messages,
        rendering: StubRenderingCapability(),
        streaming: streaming,
        chat: nil
    )
    .withResolver(resolveText)
}

// MARK: - 消息构造

/// 构造一条测试消息。
func makeStubMessage(
    conversationID: UUID,
    role: MessageRole,
    content: String = "",
    createdAt: Date = Date(timeIntervalSince1970: 1_700_000_000),
    turnID: UUID? = nil,
    toolCalls: [MessageToolCall]? = nil,
    isError: Bool = false
) -> Message {
    Message(
        id: UUID(),
        conversationID: conversationID,
        role: role,
        content: content,
        createdAt: createdAt,
        turnID: turnID,
        isError: isError,
        toolCalls: toolCalls
    )
}
