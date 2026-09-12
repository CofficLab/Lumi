import Foundation
import ProviderConversation
import ProviderProject
import Testing
@testable import PluginConversationList

@Test @MainActor func initialLoadAndHeaderReflectConversationAndProjectState() async throws {
    let conversations = DefaultConversationManager()
    let project = DefaultProjectProvider()
    try await project.openProject(at: "/workspace/One")
    _ = try conversations.createConversation(title: "One", projectPath: "/workspace/One", providerID: nil, modelName: nil)
    try await project.openProject(at: "/workspace/Two")
    _ = try conversations.createConversation(title: "Two", projectPath: "/workspace/Two", providerID: nil, modelName: nil)

    let context = makeListContext(conversations: conversations, project: project)
    let viewModel = ConversationListViewModel(
        context: context,
        attentionStore: ConversationAttentionStore(),
        sortStabilizer: ConversationSortStabilizer(),
        scope: .all
    )
    #expect(viewModel.isLoading)
    #expect(viewModel.headerVisible == false)
    #expect(viewModel.headerTitle == "所有项目的对话")

    await viewModel.loadInitialIfNeeded()
    await viewModel.loadInitialIfNeeded()

    #expect(!viewModel.isLoading)
    #expect(viewModel.conversations.count == 2)
    #expect(viewModel.hasMultipleProjects)
    #expect(viewModel.headerVisible)
    #expect(viewModel.selectedConversationID == conversations.selectedConversationID)
}

@Test @MainActor func currentProjectScopeFiltersReloadAndUpdatesProjectTitle() async throws {
    let conversations = DefaultConversationManager()
    let project = DefaultProjectProvider()
    try await project.openProject(at: "/workspace/One")
    _ = try conversations.createConversation(title: "One", projectPath: "/workspace/One", providerID: nil, modelName: nil)
    try await project.openProject(at: "/workspace/Two")
    let selectedID = try conversations.createConversation(title: "Two", projectPath: "/workspace/Two", providerID: nil, modelName: nil)
    let viewModel = ConversationListViewModel(
        context: makeListContext(conversations: conversations, project: project),
        attentionStore: ConversationAttentionStore(),
        sortStabilizer: ConversationSortStabilizer(),
        scope: .currentProject
    )

    await viewModel.loadInitialIfNeeded()

    #expect(viewModel.conversations.map(\.id) == [selectedID])
    #expect(viewModel.resolvedProjectPath == "/workspace/Two")
    #expect(viewModel.headerVisible)
    #expect(viewModel.headerTitle == "项目对话 (Two)")
    #expect(!viewModel.hasMultipleProjects)
}

@Test @MainActor func nextPageAppendsOnlyTheRemainingConversations() async throws {
    let conversations = DefaultConversationManager()
    var expectedIDs: Set<UUID> = []
    for index in 0..<41 {
        expectedIDs.insert(try conversations.createConversation(
            title: "Conversation \(index)",
            projectPath: nil,
            providerID: nil,
            modelName: nil
        ))
    }
    let viewModel = ConversationListViewModel(
        context: makeListContext(conversations: conversations),
        attentionStore: ConversationAttentionStore(),
        sortStabilizer: ConversationSortStabilizer(),
        scope: .all
    )

    await viewModel.reload()
    #expect(viewModel.conversations.count == 40)
    #expect(viewModel.hasMore)

    await viewModel.loadNextPage()
    #expect(viewModel.conversations.count == 41)
    #expect(Set(viewModel.conversations.map(\.id)) == expectedIDs)
    #expect(!viewModel.hasMore)

    await viewModel.loadNextPage()
    #expect(viewModel.conversations.count == 41)
}

@Test @MainActor func selectionClearsAttentionAndDeleteUsesConversationProvider() async throws {
    let conversations = DefaultConversationManager()
    let firstID = try conversations.createConversation(title: "First", projectPath: nil, providerID: nil, modelName: nil)
    let selectedID = try conversations.createConversation(title: "Selected", projectPath: nil, providerID: nil, modelName: nil)
    let context = makeListContext(conversations: conversations)
    let contextObserver = ConversationListContextObserver(
        conversations: conversations,
        conversationState: nil,
        context: context
    )
    let attentionStore = ConversationAttentionStore()
    let viewModel = ConversationListViewModel(
        context: context,
        attentionStore: attentionStore,
        sortStabilizer: ConversationSortStabilizer(),
        scope: .all
    )
    attentionStore.markNeedsAttention(conversationID: firstID)
    attentionStore.markNeedsAttention(conversationID: selectedID)
    #expect(viewModel.needsAttention(for: firstID))
    #expect(viewModel.needsAttention(for: selectedID))
    #expect(viewModel.conversationState(for: selectedID) == nil)

    viewModel.selectConversation(id: firstID)
    #expect(viewModel.immediateSelectionID == firstID)
    let didSelect = await waitUntil {
        viewModel.selectedConversationID == firstID && !viewModel.needsAttention(for: firstID)
    }
    #expect(didSelect)
    #expect(!viewModel.needsAttention(for: firstID))
    #expect(viewModel.needsAttention(for: selectedID))

    viewModel.deleteConversation(id: firstID)
    #expect(await conversations.conversationCount(projectPath: nil) == 1)
    viewModel.cancel()
    contextObserver.cancel()
}

@MainActor
private func makeListContext(
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
