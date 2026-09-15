import Foundation
import KernelCore
import ProviderAgentLoop
import ProviderChatSection
import ProviderConversation
import ProviderLifecycleHooks
import ProviderProject
import ProviderRailView
import ProviderToolManager
import ProviderToolbar
import Testing
@testable import PluginConversationList

@Test @MainActor func pluginBootRegistersToolbarToolAndDynamicRailTabsThenShutsThemDown() async throws {
    let kernel = KernelCoreContainer()
    let conversations = DefaultConversationManager()
    let chat = DefaultChatSectionProviding()
    let project = DefaultProjectProvider()
    let rail = DefaultRailViewProviding()
    let toolbar = DefaultToolbarProviding()
    let tools = DefaultToolManagerProviding()
    try kernel.registerProvider((any ConversationManaging).self, conversations)
    try kernel.registerProvider((any ChatSectionProviding).self, chat)
    try kernel.registerProvider((any ProjectProviding).self, project)
    try kernel.registerProvider((any RailViewProviding).self, rail)
    try kernel.registerProvider((any ToolbarProviding).self, toolbar)
    try kernel.registerProvider((any ToolManagerProviding).self, tools)
    let plugin = ConversationListPlugin()

    try plugin.onBoot(kernel: kernel)

    #expect(plugin.id == "com.coffic.lumi.plugin.conversation-list")
    #expect(plugin.order == 81)
    #expect(toolbar.toolbarItems.map(\.id) == ["\(plugin.id).conversation-list"])
    #expect(tools.tool(named: "get_recent_conversations") != nil)
    #expect(rail.tabs.isEmpty)

    _ = try conversations.createConversation(title: "First", projectPath: nil, providerID: nil, modelName: nil)
    let didRegisterChatsTab = await waitUntil {
        rail.tabs.contains { $0.id == "\(plugin.id).chats" }
    }
    #expect(didRegisterChatsTab)

    try plugin.onShutdown(kernel: kernel)

    #expect(toolbar.toolbarItems.isEmpty)
    #expect(tools.tool(named: "get_recent_conversations") == nil)
    #expect(rail.tabs.isEmpty)
}

@Test @MainActor func pluginDoesNotPartiallyBootWithoutRequiredProviders() throws {
    let kernel = KernelCoreContainer()
    let toolbar = DefaultToolbarProviding()
    let tools = DefaultToolManagerProviding()
    try kernel.registerProvider((any ToolbarProviding).self, toolbar)
    try kernel.registerProvider((any ToolManagerProviding).self, tools)
    let plugin = ConversationListPlugin()

    try plugin.onBoot(kernel: kernel)

    #expect(toolbar.toolbarItems.isEmpty)
    #expect(tools.allTools().isEmpty)
}

@Test @MainActor func pluginMarksFinishedTurnsReadOrNeedsAttentionBasedOnSelection() async throws {
    let kernel = KernelCoreContainer()
    let conversations = DefaultConversationManager()
    let chat = DefaultChatSectionProviding()
    let agentLoop = TestAgentLoop()
    try kernel.registerProvider((any ConversationManaging).self, conversations)
    try kernel.registerProvider((any ChatSectionProviding).self, chat)
    try kernel.registerProvider((any AgentLoopProviding).self, agentLoop)
    let plugin = ConversationListPlugin()
    try plugin.onBoot(kernel: kernel)

    let backgroundConversation = try conversations.createConversation(
        title: "Background",
        projectPath: nil,
        providerID: nil,
        modelName: nil
    )
    let selectedConversation = try conversations.createConversation(
        title: "Selected",
        projectPath: nil,
        providerID: nil,
        modelName: nil
    )
    plugin.attentionStore.markNeedsAttention(conversationID: backgroundConversation)
    plugin.attentionStore.markNeedsAttention(conversationID: selectedConversation)
    agentLoop.runningIDs = [backgroundConversation, selectedConversation]
    try plugin.onReady(kernel: kernel)
    try await Task.sleep(for: .milliseconds(550))

    #expect(plugin.attentionStore.needsAttention(for: backgroundConversation))
    #expect(plugin.attentionStore.needsAttention(for: selectedConversation))

    agentLoop.runningIDs = [backgroundConversation]
    let selectedConversationMarkedRead = await waitUntil {
        !plugin.attentionStore.needsAttention(for: selectedConversation)
    }
    #expect(selectedConversationMarkedRead)
    #expect(plugin.attentionStore.needsAttention(for: backgroundConversation))

    agentLoop.runningIDs = []
    let backgroundConversationMarkedAttention = await waitUntil {
        plugin.attentionStore.needsAttention(for: backgroundConversation)
    }
    #expect(backgroundConversationMarkedAttention)
    try plugin.onShutdown(kernel: kernel)
}

@MainActor
private func waitUntil(
    timeout: Duration = .seconds(1),
    condition: @MainActor () -> Bool
) async -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    while clock.now < deadline {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(5))
    }
    return condition()
}

@MainActor
private final class TestAgentLoop: AgentLoopProviding {
    var runningIDs: Set<UUID> = []

    func runTurn(in conversationID: UUID) async throws -> AgentLoopOutcome { fatalError("Unused test path") }
    func resumeTurn(in conversationID: UUID, request: AgentTurnResumeRequest) async throws -> AgentLoopOutcome { fatalError("Unused test path") }
    func cancelTurn(in conversationID: UUID) {}
    func state(for conversationID: UUID) -> AgentLoopState { isRunning(for: conversationID) ? .running : .idle }
    func suspension(for conversationID: UUID) -> AgentLoopSuspension? { nil }
    func isRunning(for conversationID: UUID) -> Bool { runningIDs.contains(conversationID) }
    func currentTurnID(for conversationID: UUID) -> UUID? { nil }
    func setLifecycleHooks(_ hooks: (any LifecycleHooksProviding)?) {}
}
