import Foundation
import KernelCore
import ProviderChatSection
import ProviderConversation
import ProviderMessage
import Testing
@testable import PluginConversationElapsedTime

// MARK: - 测试装配

/// 组装一个只注册了三个必需 Provider 的 Kernel。
@MainActor
private func makeKernel(
    chat: ElapsedTimeTestDoubles.StubChatSectionProvider,
    conversations: ElapsedTimeTestDoubles.StubConversationManager,
    messages: ElapsedTimeTestDoubles.StubMessageManager
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

// MARK: - Observer

@Suite("模型用时 Observer")
@MainActor
struct ElapsedTimeObserverTests {

    @Test("初始化时立即回放当前选中会话")
    func observerReplaysCurrentSelectionOnInit() {
        let conversationID = UUID()
        let conversations = ElapsedTimeTestDoubles.StubConversationManager(selected: conversationID)
        let messages = ElapsedTimeTestDoubles.StubMessageManager()

        var received: [UUID?] = []
        let observer = ElapsedTimeObserver(
            conversations: conversations,
            messages: messages,
            onConversationChange: { received.append($0) },
            onMessageChange: { _ in }
        )
        defer { observer.cancel() }

        #expect(received.count == 1)
        #expect(received.first ?? nil == conversationID)
    }

    @Test("选中会话变化时转发新的会话 ID")
    func observerForwardsSelectionChanges() {
        let conversations = ElapsedTimeTestDoubles.StubConversationManager()
        let messages = ElapsedTimeTestDoubles.StubMessageManager()
        let next = UUID()

        var received: [UUID?] = []
        let observer = ElapsedTimeObserver(
            conversations: conversations,
            messages: messages,
            onConversationChange: { received.append($0) },
            onMessageChange: { _ in }
        )
        defer { observer.cancel() }

        conversations.emitSelection(next)

        #expect(received.count == 2)
        #expect(received.last ?? nil == next)
    }

    @Test("五类消息变化事件都转发所属会话 ID")
    func observerForwardsEveryMessageChangeKind() {
        let conversations = ElapsedTimeTestDoubles.StubConversationManager()
        let messages = ElapsedTimeTestDoubles.StubMessageManager()
        let conversationID = UUID()
        let message = makeMessage(conversationID: conversationID)

        var received: [UUID] = []
        let observer = ElapsedTimeObserver(
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
        let conversations = ElapsedTimeTestDoubles.StubConversationManager()
        let messages = ElapsedTimeTestDoubles.StubMessageManager()

        var conversationEvents = 0
        var messageEvents = 0
        let observer = ElapsedTimeObserver(
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

        conversations.emitSelection(UUID())
        messages.emit(.cleared(conversationID: UUID()))
        #expect(conversationEvents == 1)
        #expect(messageEvents == 0)
    }

    @Test("重复取消是幂等的")
    func observerCancelIsIdempotent() {
        let conversations = ElapsedTimeTestDoubles.StubConversationManager()
        let messages = ElapsedTimeTestDoubles.StubMessageManager()

        let observer = ElapsedTimeObserver(
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

@Suite("模型用时插件生命周期")
@MainActor
struct ConversationElapsedTimePluginLifecycleTests {

    @Test("启动后注册 header 右侧贡献项")
    func bootRegistersHeaderTrailingItem() throws {
        let chat = ElapsedTimeTestDoubles.StubChatSectionProvider()
        let conversations = ElapsedTimeTestDoubles.StubConversationManager()
        let messages = ElapsedTimeTestDoubles.StubMessageManager()
        let kernel = makeKernel(chat: chat, conversations: conversations, messages: messages)

        let plugin = ConversationElapsedTimePlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(chat.barItemIDs == ["com.coffic.lumi.plugin.conversation-elapsed-time.header"])
        #expect(chat.addedBarItems.first?.placement == .headerTrailing)
    }

    @Test("贡献项排在 token 用量旁边")
    func contributionSitsNextToTokenUsage() throws {
        let chat = ElapsedTimeTestDoubles.StubChatSectionProvider()
        let conversations = ElapsedTimeTestDoubles.StubConversationManager()
        let messages = ElapsedTimeTestDoubles.StubMessageManager()
        let kernel = makeKernel(chat: chat, conversations: conversations, messages: messages)

        let plugin = ConversationElapsedTimePlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(chat.addedBarItems.first?.order == 92)
    }

    @Test("缺少必需 Provider 时不注册贡献项也不抛错")
    func bootWithoutProvidersIsNoop() throws {
        let kernel = KernelCoreContainer()
        let plugin = ConversationElapsedTimePlugin()

        try plugin.onBoot(kernel: kernel)

        #expect(plugin.toolbarState.selectedConversationID == nil)
    }

    @Test("启动时把当前选中会话同步到 header 状态")
    func bootSyncsSelectedConversationToToolbarState() throws {
        let conversationID = UUID()
        let chat = ElapsedTimeTestDoubles.StubChatSectionProvider()
        let conversations = ElapsedTimeTestDoubles.StubConversationManager(selected: conversationID)
        let messages = ElapsedTimeTestDoubles.StubMessageManager()
        let kernel = makeKernel(chat: chat, conversations: conversations, messages: messages)

        let plugin = ConversationElapsedTimePlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(plugin.toolbarState.selectedConversationID == conversationID)
    }

    @Test("选中会话变化后 header 状态跟随更新")
    func selectionChangeUpdatesToolbarState() throws {
        let chat = ElapsedTimeTestDoubles.StubChatSectionProvider()
        let conversations = ElapsedTimeTestDoubles.StubConversationManager()
        let messages = ElapsedTimeTestDoubles.StubMessageManager()
        let kernel = makeKernel(chat: chat, conversations: conversations, messages: messages)

        let plugin = ConversationElapsedTimePlugin()
        try plugin.onBoot(kernel: kernel)

        let next = UUID()
        conversations.emitSelection(next)

        #expect(plugin.toolbarState.selectedConversationID == next)
    }

    @Test("重复启动会注销上一轮的观察者")
    func secondBootCancelsPreviousObserver() throws {
        let chat = ElapsedTimeTestDoubles.StubChatSectionProvider()
        let conversations = ElapsedTimeTestDoubles.StubConversationManager()
        let messages = ElapsedTimeTestDoubles.StubMessageManager()
        let kernel = makeKernel(chat: chat, conversations: conversations, messages: messages)

        let plugin = ConversationElapsedTimePlugin()
        try plugin.onBoot(kernel: kernel)
        try plugin.onBoot(kernel: kernel)

        #expect(conversations.selectedHandle.cancelCount == 1)
        #expect(messages.changeHandle.cancelCount == 1)
    }

    @Test("关闭时移除贡献项并注销观察者")
    func shutdownRemovesItemAndCancelsObserver() throws {
        let chat = ElapsedTimeTestDoubles.StubChatSectionProvider()
        let conversations = ElapsedTimeTestDoubles.StubConversationManager()
        let messages = ElapsedTimeTestDoubles.StubMessageManager()
        let kernel = makeKernel(chat: chat, conversations: conversations, messages: messages)

        let plugin = ConversationElapsedTimePlugin()
        try plugin.onBoot(kernel: kernel)
        try plugin.onShutdown(kernel: kernel)

        #expect(chat.removedBarItemIDs == ["com.coffic.lumi.plugin.conversation-elapsed-time.header"])
        #expect(chat.barItemIDs.isEmpty)
        #expect(conversations.selectedHandle.cancelCount == 1)
        #expect(messages.changeHandle.cancelCount == 1)
    }

    @Test("未启动就关闭不会抛错")
    func shutdownWithoutBootIsSafe() throws {
        let kernel = KernelCoreContainer()
        let plugin = ConversationElapsedTimePlugin()

        try plugin.onShutdown(kernel: kernel)
    }
}
