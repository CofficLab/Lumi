import Foundation
import KernelCore
import ProviderChatSection
import ProviderConversation
import ProviderMessage
import Testing
@testable import PluginMessageListEmpty

@Test @MainActor func pluginShowsEmptyStateOnlyForSelectedConversationWithoutVisibleMessages() async throws {
    let kernel = KernelCoreContainer()
    let conversations = DefaultConversationManager()
    let messages = DefaultMessageManager()
    let chat = DefaultChatSectionProviding()
    try kernel.registerProvider((any ChatSectionProviding).self, chat)
    try kernel.registerProvider((any ConversationManaging).self, conversations)
    try kernel.registerProvider((any MessageManaging).self, messages)
    let plugin = PluginMessageListEmptyPlugin()

    try plugin.onBoot(kernel: kernel)
    #expect(chat.items.map(\.id) == [plugin.id])
    #expect(chat.items.first?.exclusiveGroup == "message-list")
    #expect(chat.items.first?.fillsRemainingHeight == true)

    let firstID = try conversations.createConversation(title: "First", projectPath: nil, providerID: nil, modelName: nil)
    let selectedID = try conversations.createConversation(title: "Selected", projectPath: nil, providerID: nil, modelName: nil)
    let firstMessageID = UUID()
    messages.insertMessage(
        Message(id: firstMessageID, conversationID: firstID, role: .user, content: "Non-selected"),
        to: firstID
    )
    await settleRegistrationEvaluation()
    #expect(chat.items.map(\.id) == [plugin.id])

    messages.insertMessage(Message(conversationID: selectedID, role: .tool, content: "Tool output"), to: selectedID)
    await settleRegistrationEvaluation()
    #expect(chat.items.map(\.id) == [plugin.id])

    let visibleMessageID = UUID()
    messages.insertMessage(Message(id: visibleMessageID, conversationID: selectedID, role: .user, content: "Hello"), to: selectedID)
    await settleRegistrationEvaluation()
    // 空态 item 常驻注册，可见性完全由 `isActive` 表达（见 `shouldRenderEmptyState`）。
    #expect(!chat.items.isEmpty)
    #expect(!chat.isEmptyStateRendering)

    messages.clearMessages(in: selectedID)
    await settleRegistrationEvaluation()
    #expect(chat.isEmptyStateRendering)

    conversations.selectConversation(id: firstID)
    await settleRegistrationEvaluation()
    // firstID 只有一条 user 消息 → 空态仍不渲染。
    #expect(!chat.isEmptyStateRendering)

    messages.deleteMessage(id: firstMessageID, in: firstID)
    await settleRegistrationEvaluation()
    #expect(chat.isEmptyStateRendering)

    conversations.deselectConversation()
    #expect(chat.items.map(\.id) == [plugin.id])

    try plugin.onShutdown(kernel: kernel)
    #expect(chat.items.isEmpty)

    messages.clearMessages(in: selectedID)
    conversations.selectConversation(id: selectedID)
    await settleRegistrationEvaluation()
    #expect(chat.items.isEmpty)
}

@MainActor
private func settleRegistrationEvaluation() async {
    // The plugin evaluates persisted state in a child task that performs an
    // async read. `Task.yield()` does not advance wall-clock time, so give the
    // evaluation real time to finish instead of guessing how many yields it takes.
    for _ in 0..<100 {
        try? await Task.sleep(nanoseconds: 5_000_000)
    }
}

/// 空态 item 现已常驻注册，可见性完全由 `isActive` 表达，
/// 因此断言「是否渲染空态」而非「是否注册 item」。
private extension DefaultChatSectionProviding {
    var isEmptyStateRendering: Bool {
        items.contains { $0.id == "com.coffic.lumi.plugin.message-list.empty" && $0.isActive() }
    }
}

@Test @MainActor func pluginCanProvideNoSelectionEmptyStateWithoutOptionalProviders() throws {
    let kernel = KernelCoreContainer()
    let chat = DefaultChatSectionProviding()
    try kernel.registerProvider((any ChatSectionProviding).self, chat)
    let plugin = PluginMessageListEmptyPlugin()

    try plugin.onBoot(kernel: kernel)

    #expect(chat.items.map(\.id) == [plugin.id])
    try plugin.onShutdown(kernel: kernel)
    #expect(chat.items.isEmpty)
}

@Test @MainActor func pluginDoesNotBootWithoutChatSectionProvider() throws {
    let plugin = PluginMessageListEmptyPlugin()

    try plugin.onBoot(kernel: KernelCoreContainer())
}
