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
    // 插件常驻注册两个槽位：空态本体 + 底部 activity strip（a362063f1 新增）。
    let expectedItemIDs = [plugin.id, plugin.activityItemID]
    #expect(chat.items.map(\.id) == expectedItemIDs)
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
    #expect(chat.items.map(\.id) == expectedItemIDs)

    messages.insertMessage(Message(conversationID: selectedID, role: .tool, content: "Tool output"), to: selectedID)
    await settleRegistrationEvaluation()
    #expect(chat.items.map(\.id) == expectedItemIDs)

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
    #expect(chat.items.map(\.id) == expectedItemIDs)

    try plugin.onShutdown(kernel: kernel)
    #expect(chat.items.isEmpty)

    messages.clearMessages(in: selectedID)
    conversations.selectConversation(id: selectedID)
    await settleRegistrationEvaluation()
    #expect(chat.items.isEmpty)
}

/// Lets the plugin's registration evaluation reach a settled conclusion.
///
/// The evaluation runs in a child task that performs an async SwiftData read
/// and only then calls `applyRegistration`. Rather than guessing how many
/// yields that takes, drain the main actor until no further work is pending:
/// once the queue has no runnable item left, every task that was going to
/// resolve has resolved. This replaces an earlier sleep loop that burned a fixed
/// ~0.5 s per call and could still flake on a loaded machine.
@MainActor
private func settleRegistrationEvaluation() async {
    await Task.yield()
    for _ in 0..<50 {
        await Task.yield()
    }
}

/// Empty-state item 常驻注册，可见性完全由 `isActive` 表达，
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

    #expect(chat.items.map(\.id) == [plugin.id, plugin.activityItemID])
    try plugin.onShutdown(kernel: kernel)
    #expect(chat.items.isEmpty)
}

@Test @MainActor func pluginDoesNotBootWithoutChatSectionProvider() throws {
    let plugin = PluginMessageListEmptyPlugin()

    try plugin.onBoot(kernel: KernelCoreContainer())
}

/// 判定被取消、以及判定因「会话已被换掉」而放弃时，状态都不得悬挂。
///
/// 曾经的疑问：任务里的
/// `guard !Task.isCancelled, selectedConversationID == selectedID else { return }`
/// 是静默返回，会不会让 `registrationState` 永久停在 `.evaluating`、
/// 导致空态再也不渲染？答案是**不会**——`scheduleRegistrationEvaluation`
/// 的每个出口都会落地状态，而任何让状态悬挂的放弃都必然伴随一个
/// 触发新评估的调用（会话切换、消息变更）。测试锁定这个不变量，
/// 防止将来把某个出口改成静默 return 时无声退化。
///
/// 覆盖两条放弃路径：
/// - `Task.isCancelled`：连续切换会话，后一次取消前一次仍在途的任务；
/// - 会话不匹配：旧判定在途时把选中态换到另一个会话。
@Test @MainActor func abandonedEvaluationNeverLeavesStateHanging() async throws {
    let kernel = KernelCoreContainer()
    let conversations = DefaultConversationManager()
    let messages = DefaultMessageManager()
    let chat = DefaultChatSectionProviding()
    try kernel.registerProvider((any ChatSectionProviding).self, chat)
    try kernel.registerProvider((any ConversationManaging).self, conversations)
    try kernel.registerProvider((any MessageManaging).self, messages)
    let plugin = PluginMessageListEmptyPlugin()
    try plugin.onBoot(kernel: kernel)

    let busyID = try conversations.createConversation(title: "Busy", projectPath: nil, providerID: nil, modelName: nil)
    let idleID = try conversations.createConversation(title: "Idle", projectPath: nil, providerID: nil, modelName: nil)
    messages.insertMessage(
        Message(conversationID: busyID, role: .user, content: "hi"),
        to: busyID
    )

    // 路径一：会话不匹配 —— busyID 的判定在途时切到无消息的 idleID。
    conversations.selectConversation(id: busyID)
    conversations.selectConversation(id: idleID)
    await settleRegistrationEvaluation()
    #expect(
        chat.isEmptyStateRendering,
        "旧判定被放弃后状态悬挂：idleID 无消息却未渲染空态"
    )

    // 路径二：任务取消 —— 连续切换，后一次取消前一次仍在途的任务。
    conversations.selectConversation(id: busyID)
    conversations.selectConversation(id: idleID)
    conversations.selectConversation(id: busyID)
    await settleRegistrationEvaluation()
    #expect(
        !chat.isEmptyStateRendering,
        "busyID 有消息却渲染了空态"
    )
}
