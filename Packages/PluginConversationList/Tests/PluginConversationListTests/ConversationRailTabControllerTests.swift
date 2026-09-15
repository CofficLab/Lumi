import Foundation
import ProviderConversation
import ProviderProject
import ProviderRailView
import Testing
@testable import PluginConversationList

@Test @MainActor func railTabsFollowConversationAndCurrentProjectAvailability() async throws {
    let conversations = DefaultConversationManager()
    let project = DefaultProjectProvider()
    try await project.openProject(at: "/workspace/One")
    let context = makeContext(conversations: conversations, project: project)
    let attentionStore = ConversationAttentionStore()
    let sortStabilizer = ConversationSortStabilizer()
    let chatsViewModel = makeViewModel(context: context, attentionStore: attentionStore, sortStabilizer: sortStabilizer, scope: .all)
    let projectViewModel = makeViewModel(context: context, attentionStore: attentionStore, sortStabilizer: sortStabilizer, scope: .currentProject)
    let controller = ConversationRailTabController(
        context: context,
        attentionStore: attentionStore,
        sortStabilizer: sortStabilizer,
        chatsViewModel: chatsViewModel,
        projectViewModel: projectViewModel,
        order: 81,
        pluginID: "test.conversation-list"
    )
    let rail = DefaultRailViewProviding()
    controller.start(rail: rail)
    try await Task.sleep(for: .milliseconds(120))
    #expect(rail.tabs.isEmpty)

    let firstID = try conversations.createConversation(title: "One", projectPath: "/workspace/One", providerID: nil, modelName: nil)
    let chatsTabID = "test.conversation-list.chats"
    let projectTabID = "test.conversation-list.project-chats"
    let firstConversationRegistered = await waitUntil { rail.tabs.contains { $0.id == chatsTabID } }
    #expect(firstConversationRegistered)
    #expect(!rail.tabs.contains { $0.id == projectTabID })

    let secondID = try conversations.createConversation(title: "Two", projectPath: "/workspace/Two", providerID: nil, modelName: nil)
    let projectConversationRegistered = await waitUntil { rail.tabs.contains { $0.id == projectTabID } }
    #expect(projectConversationRegistered)

    try await project.openProject(at: "/workspace/Three")
    let projectTabRemovedWhenCurrentProjectIsEmpty = await waitUntil { !rail.tabs.contains { $0.id == projectTabID } }
    #expect(projectTabRemovedWhenCurrentProjectIsEmpty)
    try await project.openProject(at: "/workspace/Two")
    let projectTabRestoredForCurrentProject = await waitUntil { rail.tabs.contains { $0.id == projectTabID } }
    #expect(projectTabRestoredForCurrentProject)

    conversations.deleteConversation(id: secondID)
    let projectTabRemovedWhenOnlyOneProjectRemains = await waitUntil { !rail.tabs.contains { $0.id == projectTabID } }
    #expect(projectTabRemovedWhenOnlyOneProjectRemains)
    conversations.deleteConversation(id: firstID)
    let chatsTabRemovedWhenLibraryIsEmpty = await waitUntil { !rail.tabs.contains { $0.id == chatsTabID } }
    #expect(chatsTabRemovedWhenLibraryIsEmpty)

    controller.stop()
}

@Test @MainActor func stoppingRailControllerCancelsRefreshSubscriptions() async throws {
    let conversations = DefaultConversationManager()
    let context = makeContext(conversations: conversations)
    let attentionStore = ConversationAttentionStore()
    let sortStabilizer = ConversationSortStabilizer()
    let chatsViewModel = makeViewModel(context: context, attentionStore: attentionStore, sortStabilizer: sortStabilizer, scope: .all)
    let projectViewModel = makeViewModel(context: context, attentionStore: attentionStore, sortStabilizer: sortStabilizer, scope: .currentProject)
    let controller = ConversationRailTabController(
        context: context,
        attentionStore: attentionStore,
        sortStabilizer: sortStabilizer,
        chatsViewModel: chatsViewModel,
        projectViewModel: projectViewModel,
        order: 81,
        pluginID: "test.conversation-list"
    )
    let rail = DefaultRailViewProviding()
    controller.start(rail: rail)
    try await Task.sleep(for: .milliseconds(120))
    controller.stop()

    _ = try conversations.createConversation(title: "After stop", projectPath: nil, providerID: nil, modelName: nil)
    try await Task.sleep(for: .milliseconds(120))

    #expect(rail.tabs.isEmpty)
}

@MainActor
private func makeContext(
    conversations: any ConversationManaging,
    project: (any ProjectProviding)? = nil
) -> ConversationListContext {
    ConversationListContext(
        conversations: conversations,
        project: project,
        agentTurn: nil,
        conversationState: nil,
        chat: nil
    )
}

@MainActor
private func makeViewModel(
    context: ConversationListContext,
    attentionStore: ConversationAttentionStore,
    sortStabilizer: ConversationSortStabilizer,
    scope: ConversationListViewModel.Scope
) -> ConversationListViewModel {
    ConversationListViewModel(
        context: context,
        attentionStore: attentionStore,
        sortStabilizer: sortStabilizer,
        scope: scope
    )
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
