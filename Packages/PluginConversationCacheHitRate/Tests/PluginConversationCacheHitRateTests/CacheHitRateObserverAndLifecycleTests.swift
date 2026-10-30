import Foundation
import KernelCore
import ProviderChatSection
import ProviderConversation
import ProviderMessage
import Testing
@testable import PluginConversationCacheHitRate

// MARK: - 测试装配

/// 组装一个只注册了三个必需 Provider 的 Kernel。
@MainActor
private func makeKernel(
    chat: CacheHitRateTestDoubles.StubChatSectionProvider,
    conversations: CacheHitRateTestDoubles.StubConversationManager,
    messages: CacheHitRateTestDoubles.StubMessageManager
) -> KernelCoreContainer {
    let kernel = KernelCoreContainer()
    try? kernel.registerProvider((any ChatSectionProviding).self, chat)
    try? kernel.registerProvider((any ConversationManaging).self, conversations)
    try? kernel.registerProvider((any MessageManaging).self, messages)
    return kernel
}

private func makeMessage(
    conversationID: UUID = UUID(),
    role: MessageRole = .assistant,
    content: String = "message"
) -> Message {
    Message(conversationID: conversationID, role: role, content: content)
}

// MARK: - CacheHitRateObserver

@Suite("缓存命中率 Observer")
@MainActor
struct CacheHitRateObserverTests {

    @Test("初始化时立即回放当前选中会话")
    func observerReplaysCurrentSelectionOnInit() {
        let conversationID = UUID()
        let conversations = CacheHitRateTestDoubles.StubConversationManager(selected: conversationID)
        let messages = CacheHitRateTestDoubles.StubMessageManager()

        var received: [UUID?] = []
        let observer = CacheHitRateObserver(
            conversations: conversations,
            messages: messages,
            onConversationChange: { received.append($0) },
            onMessageChange: { _ in }
        )
        defer { observer.cancel() }

        #expect(received.count == 1)
        let replayed = received.first ?? nil
        #expect(replayed == conversationID)
    }

    @Test("选中会话变化时转发新的会话 ID")
    func observerForwardsSelectionChanges() {
        let conversations = CacheHitRateTestDoubles.StubConversationManager()
        let messages = CacheHitRateTestDoubles.StubMessageManager()
        let next = UUID()

        var received: [UUID?] = []
        let observer = CacheHitRateObserver(
            conversations: conversations,
            messages: messages,
            onConversationChange: { received.append($0) },
            onMessageChange: { _ in }
        )
        defer { observer.cancel() }

        conversations.emitSelection(next)

        #expect(received.count == 2)
        let latest = received.last ?? nil
        #expect(latest == next)
    }

    @Test("五类消息变化事件都转发所属会话 ID")
    func observerForwardsEveryMessageChangeKind() {
        let conversations = CacheHitRateTestDoubles.StubConversationManager()
        let messages = CacheHitRateTestDoubles.StubMessageManager()
        let conversationID = UUID()
        let message = makeMessage(conversationID: conversationID)

        var received: [UUID] = []
        let observer = CacheHitRateObserver(
            conversations: conversations,
            messages: messages,
            onConversationChange: { _ in },
            onMessageChange: { received.append($0) }
        )
        defer { observer.cancel() }

        messages.emit(.inserted(message, conversationID: conversationID))
        messages.emit(.persisted(message, conversationID: conversationID))
        messages.emit(.updated(conversationID: conversationID))
        messages.emit(.deleted(messageID: message.id, conversationID: conversationID))
        messages.emit(.cleared(conversationID: conversationID))

        #expect(received == Array(repeating: conversationID, count: 5))
    }

    @Test("取消后释放两个订阅并停止转发")
    func observerCancelReleasesSubscriptions() {
        let conversations = CacheHitRateTestDoubles.StubConversationManager()
        let messages = CacheHitRateTestDoubles.StubMessageManager()

        var conversationEvents = 0
        var messageEvents = 0
        let observer = CacheHitRateObserver(
            conversations: conversations,
            messages: messages,
            onConversationChange: { _ in conversationEvents += 1 },
            onMessageChange: { _ in messageEvents += 1 }
        )

        observer.cancel()

        #expect(conversations.selectedHandle.cancelCount == 1)
        #expect(messages.changeHandle.cancelCount == 1)
        #expect(conversations.isObserving == false)
        #expect(messages.isObserving == false)

        // 取消后 Provider 不应再派发到已注销的闭包。
        conversations.emitSelection(UUID())
        messages.emit(.cleared(conversationID: UUID()))
        #expect(conversationEvents == 1)
        #expect(messageEvents == 0)
    }

    @Test("重复取消是幂等的")
    func observerCancelIsIdempotent() {
        let conversations = CacheHitRateTestDoubles.StubConversationManager()
        let messages = CacheHitRateTestDoubles.StubMessageManager()

        let observer = CacheHitRateObserver(
            conversations: conversations,
            messages: messages,
            onConversationChange: { _ in },
            onMessageChange: { _ in }
        )

        observer.cancel()
        observer.cancel()

        #expect(conversations.selectedHandle.cancelCount == 1)
        #expect(messages.changeHandle.cancelCount == 1)
    }
}

// MARK: - 插件生命周期

@Suite("缓存命中率插件生命周期")
@MainActor
struct CacheHitRatePluginLifecycleTests {

    @Test("启动后注册工具栏按钮")
    func bootRegistersToolbarButton() throws {
        let chat = CacheHitRateTestDoubles.StubChatSectionProvider()
        let conversations = CacheHitRateTestDoubles.StubConversationManager()
        let messages = CacheHitRateTestDoubles.StubMessageManager()
        let kernel = makeKernel(chat: chat, conversations: conversations, messages: messages)

        let plugin = ConversationCacheHitRatePlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(chat.barItemIDs == ["com.coffic.lumi.plugin.conversation-cache-hit-rate.toolbar-button"])
    }

    @Test("缺少必需 Provider 时不注册按钮也不抛错")
    func bootWithoutProvidersIsNoop() throws {
        let kernel = KernelCoreContainer()
        let plugin = ConversationCacheHitRatePlugin()

        try plugin.onBoot(kernel: kernel)

        #expect(plugin.toolbarState.selectedConversationID == nil)
    }

    @Test("启动时把当前选中会话同步到工具栏状态")
    func bootSyncsSelectedConversationToToolbarState() throws {
        let conversationID = UUID()
        let chat = CacheHitRateTestDoubles.StubChatSectionProvider()
        let conversations = CacheHitRateTestDoubles.StubConversationManager(selected: conversationID)
        let messages = CacheHitRateTestDoubles.StubMessageManager()
        let kernel = makeKernel(chat: chat, conversations: conversations, messages: messages)

        let plugin = ConversationCacheHitRatePlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(plugin.toolbarState.selectedConversationID == conversationID)
    }

    @Test("选中会话变化后工具栏状态跟随更新")
    func selectionChangeUpdatesToolbarState() throws {
        let chat = CacheHitRateTestDoubles.StubChatSectionProvider()
        let conversations = CacheHitRateTestDoubles.StubConversationManager()
        let messages = CacheHitRateTestDoubles.StubMessageManager()
        let kernel = makeKernel(chat: chat, conversations: conversations, messages: messages)

        let plugin = ConversationCacheHitRatePlugin()
        try plugin.onBoot(kernel: kernel)

        let next = UUID()
        conversations.emitSelection(next)

        #expect(plugin.toolbarState.selectedConversationID == next)
    }

    @Test("重复启动会注销上一轮的观察者")
    func secondBootCancelsPreviousObserver() throws {
        let chat = CacheHitRateTestDoubles.StubChatSectionProvider()
        let conversations = CacheHitRateTestDoubles.StubConversationManager()
        let messages = CacheHitRateTestDoubles.StubMessageManager()
        let kernel = makeKernel(chat: chat, conversations: conversations, messages: messages)

        let plugin = ConversationCacheHitRatePlugin()
        try plugin.onBoot(kernel: kernel)
        try plugin.onBoot(kernel: kernel)

        #expect(conversations.selectedHandle.cancelCount == 1)
        #expect(messages.changeHandle.cancelCount == 1)
    }

    @Test("关闭时移除工具栏按钮并注销观察者")
    func shutdownRemovesButtonAndCancelsObserver() throws {
        let chat = CacheHitRateTestDoubles.StubChatSectionProvider()
        let conversations = CacheHitRateTestDoubles.StubConversationManager()
        let messages = CacheHitRateTestDoubles.StubMessageManager()
        let kernel = makeKernel(chat: chat, conversations: conversations, messages: messages)

        let plugin = ConversationCacheHitRatePlugin()
        try plugin.onBoot(kernel: kernel)
        try plugin.onShutdown(kernel: kernel)

        #expect(chat.removedBarItemIDs == ["com.coffic.lumi.plugin.conversation-cache-hit-rate.toolbar-button"])
        #expect(chat.barItemIDs.isEmpty)
        #expect(conversations.selectedHandle.cancelCount == 1)
        #expect(messages.changeHandle.cancelCount == 1)
    }

    @Test("未启动就关闭不会抛错")
    func shutdownWithoutBootIsSafe() throws {
        let kernel = KernelCoreContainer()
        let plugin = ConversationCacheHitRatePlugin()

        try plugin.onShutdown(kernel: kernel)
    }
}

// MARK: - 工具栏状态

@Suite("缓存命中率工具栏状态")
@MainActor
struct CacheHitRateToolbarStateTests {

    @Test("多个观察者都能收到事件")
    func multipleObserversReceiveEvents() {
        let state = CacheHitRateToolbarState()
        var first: [CacheHitRateToolbarState.Event] = []
        var second: [CacheHitRateToolbarState.Event] = []
        let firstHandle = state.addObserver { first.append($0) }
        let secondHandle = state.addObserver { second.append($0) }
        defer {
            firstHandle.cancel()
            secondHandle.cancel()
        }

        let conversationID = UUID()
        state.setSelectedConversationID(conversationID)
        state.markMessagesChanged(conversationID: conversationID)

        #expect(first.count == 2)
        #expect(second.count == 2)
    }

    @Test("注销一个观察者不影响另一个")
    func cancellingOneObserverKeepsOther() {
        let state = CacheHitRateToolbarState()
        var first: [CacheHitRateToolbarState.Event] = []
        var second: [CacheHitRateToolbarState.Event] = []
        let firstHandle = state.addObserver { first.append($0) }
        let secondHandle = state.addObserver { second.append($0) }
        defer { secondHandle.cancel() }

        firstHandle.cancel()
        state.markMessagesChanged(conversationID: UUID())

        #expect(first.isEmpty)
        #expect(second.count == 1)
    }

    @Test("重复注销同一个观察者只生效一次")
    func cancellingTwiceIsIdempotent() {
        let state = CacheHitRateToolbarState()
        var events: [CacheHitRateToolbarState.Event] = []
        let handle = state.addObserver { events.append($0) }

        handle.cancel()
        handle.cancel()
        state.markMessagesChanged(conversationID: UUID())

        #expect(events.isEmpty)
    }

    @Test("消息变化事件携带会话 ID")
    func messagesChangedCarriesConversationID() {
        let state = CacheHitRateToolbarState()
        var events: [CacheHitRateToolbarState.Event] = []
        let handle = state.addObserver { events.append($0) }
        defer { handle.cancel() }

        let conversationID = UUID()
        state.markMessagesChanged(conversationID: conversationID)

        #expect(events.count == 1)
        guard case let .messagesChanged(received) = events[0] else {
            Issue.record("期望 .messagesChanged 事件")
            return
        }
        #expect(received == conversationID)
    }

    @Test("选中会话变化事件携带新的会话 ID")
    func selectionChangedCarriesConversationID() {
        let state = CacheHitRateToolbarState()
        var events: [CacheHitRateToolbarState.Event] = []
        let handle = state.addObserver { events.append($0) }
        defer { handle.cancel() }

        let conversationID = UUID()
        state.setSelectedConversationID(conversationID)

        #expect(events.count == 1)
        guard case let .selectedConversationChanged(received) = events[0] else {
            Issue.record("期望 .selectedConversationChanged 事件")
            return
        }
        #expect(received == conversationID)
    }
}

// MARK: - 采样解析

@Suite("缓存命中率采样解析")
struct CacheHitRateMetricsTests {

    @Test("metadata 中非数字的缓存用量被忽略")
    func metadataWithNonNumericValueIsRejected() {
        let message = Message(
            conversationID: UUID(),
            role: .assistant,
            content: "broken",
            metadata: [
                "cachedInputTokens": "not-a-number",
                "cacheTotalInputTokens": "100",
            ]
        )

        #expect(CacheHitRateRequestMetrics.parse(message) == nil)
    }

    @Test("metadata 只有缓存用量、没有总量时返回 nil")
    func metadataWithoutTotalIsRejected() {
        let message = Message(
            conversationID: UUID(),
            role: .assistant,
            content: "partial",
            metadata: ["cachedInputTokens": "50"]
        )

        #expect(CacheHitRateRequestMetrics.parse(message) == nil)
    }

    @Test("强类型字段优先于 metadata 回退")
    func typedFieldsWinOverMetadata() {
        let message = Message(
            conversationID: UUID(),
            role: .assistant,
            content: "typed",
            metadata: [
                "cachedInputTokens": "10",
                "cacheTotalInputTokens": "20",
            ],
            cachedInputTokenCount: 40,
            cacheTotalInputTokenCount: 80
        )

        let metrics = CacheHitRateRequestMetrics.parse(message)
        #expect(metrics?.cachedTokens == 40)
        #expect(metrics?.totalTokens == 80)
        #expect(metrics?.hitRate == 0.5)
    }

    @Test("缓存用量被夹取到不超过总输入量")
    func cachedTokensAreClamped() {
        let message = Message(
            conversationID: UUID(),
            role: .assistant,
            content: "overflow",
            cachedInputTokenCount: 500,
            cacheTotalInputTokenCount: 100
        )

        let metrics = CacheHitRateRequestMetrics.parse(message)
        #expect(metrics?.cachedTokens == 100)
        #expect(metrics?.hitRate == 1.0)
    }

    @Test("非 assistant 消息不参与采样")
    func nonAssistantMessageIsSkipped() {
        let message = Message(
            conversationID: UUID(),
            role: .user,
            content: "hi",
            cachedInputTokenCount: 50,
            cacheTotalInputTokenCount: 100
        )

        #expect(CacheHitRateRequestMetrics.parse(message) == nil)
    }
}

// MARK: - 历史曲线

@Suite("缓存命中率历史")
struct CacheHitRateHistoryEdgeCaseTests {

    @Test("空历史的统计值均为 nil")
    func emptyHistoryHasNoStatistics() {
        let history = CacheHitRateHistory.empty

        #expect(history.isEmpty)
        #expect(history.minimumHitRate == nil)
        #expect(history.averageHitRate == nil)
        #expect(history.maximumHitRate == nil)
        #expect(history.latestCumulativeHitRate == nil)
    }

    @Test("同一时间戳按 UUID 排序保证稳定顺序")
    func sameTimestampIsOrderedByUUID() {
        let conversationID = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_000)
        let first = Message(
            conversationID: conversationID,
            role: .assistant,
            content: "a",
            createdAt: createdAt,
            cachedInputTokenCount: 10,
            cacheTotalInputTokenCount: 100
        )
        let second = Message(
            conversationID: conversationID,
            role: .assistant,
            content: "b",
            createdAt: createdAt,
            cachedInputTokenCount: 20,
            cacheTotalInputTokenCount: 100
        )

        let history = CacheHitRateHistory.build(from: [second, first])

        #expect(history.samples.count == 2)
        #expect(history.samples.map(\.index) == [0, 1])
        #expect(history.samples.map(\.cachedTokens) == [10, 20].sorted())
    }

    @Test("累计命中率按 token 加权而非算术平均")
    func cumulativeRateIsTokenWeighted() {
        let conversationID = UUID()
        let messages = [
            Message(
                conversationID: conversationID,
                role: .assistant,
                content: "miss",
                createdAt: Date(timeIntervalSince1970: 1),
                cachedInputTokenCount: 0,
                cacheTotalInputTokenCount: 900
            ),
            Message(
                conversationID: conversationID,
                role: .assistant,
                content: "hit",
                createdAt: Date(timeIntervalSince1970: 2),
                cachedInputTokenCount: 100,
                cacheTotalInputTokenCount: 100
            ),
        ]

        let history = CacheHitRateHistory.build(from: messages)

        #expect(history.samples.count == 2)
        let latest = history.latestCumulativeHitRate ?? 0
        #expect(abs(latest - 0.1) < 1e-9)
        // 算术平均是 0.5，与加权值不同，说明两条口径确实不一致。
        let average = history.averageHitRate ?? 0
        #expect(abs(average - 0.5) < 1e-9)
    }

    @Test("预览样例消息可构造出非空历史")
    func previewMessagesProduceHistory() {
        let history = CacheHitRateHistory.build(from: CacheHitRateHistory.previewMessages)

        #expect(history.samples.count == 8)
        #expect(history.isEmpty == false)
        #expect(CacheHitRateHistory.preview.samples.count == 8)
    }
}
