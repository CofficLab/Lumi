import Foundation
import ProviderChatSection
import ProviderConversation
import ProviderProject
import Testing
@testable import PluginConversationList

@Test @MainActor func toolbarRefreshesConversationPresenceAndObservesChatVisibility() async throws {
    let conversations = DefaultConversationManager()
    let chat = DefaultChatSectionProviding()
    let context = makeContext(conversations: conversations, chat: chat)
    let viewModel = ConversationListToolbarViewModel(context: context)

    #expect(viewModel.isChatSectionVisible)
    #expect(viewModel.hasAnyConversations)
    await viewModel.refreshConversationPresence()
    #expect(!viewModel.hasAnyConversations)

    _ = try conversations.createConversation(title: "One", projectPath: nil, providerID: nil, modelName: nil)
    await viewModel.refreshConversationPresence()
    #expect(viewModel.hasAnyConversations)

    chat.setVisible(false)
    #expect(!viewModel.isChatSectionVisible)
    viewModel.cancel()
    chat.setVisible(true)
    context.markConversationsChanged()
    #expect(!viewModel.isChatSectionVisible)
    #expect(viewModel.contextRevision == 0)
}

@Test @MainActor func toolbarShowsCurrentProjectScopeOnlyWhenItHasConversationsAndOthersExist() async throws {
    let conversations = DefaultConversationManager()
    let project = DefaultProjectProvider()
    let viewModel = ConversationListToolbarViewModel(
        context: makeContext(conversations: conversations, project: project)
    )

    viewModel.pickerSelection = .currentProject
    #expect(viewModel.selectedScope == .allProjects)

    try await project.openProject(at: "/workspace/First")
    _ = try conversations.createConversation(title: "First", projectPath: "/workspace/First", providerID: nil, modelName: nil)
    await viewModel.refreshProjectScopeVisibility()
    #expect(viewModel.hasMultipleProjects == false)
    #expect(!viewModel.showsCurrentProjectScope)
    #expect(!viewModel.currentProjectHasConversations)

    try await project.openProject(at: "/workspace/Second")
    _ = try conversations.createConversation(title: "Second", projectPath: "/workspace/Second", providerID: nil, modelName: nil)
    await viewModel.refreshProjectScopeVisibility()
    #expect(viewModel.hasMultipleProjects)
    #expect(viewModel.currentProjectHasConversations)
    #expect(viewModel.showsCurrentProjectScope)
    #expect(viewModel.currentProjectPath == "/workspace/Second")
    #expect(viewModel.currentProjectName == "Second")
    #expect(viewModel.currentProjectTabTitle == "Second")

    viewModel.pickerSelection = .currentProject
    #expect(viewModel.pickerSelection == .currentProject)
    await project.closeProject()
    await viewModel.refreshProjectScopeVisibility()
    #expect(!viewModel.showsCurrentProjectScope)
    #expect(viewModel.currentProjectTabTitle == "当前项目")
    #expect(viewModel.pickerSelection == .allProjects)
}

@MainActor
private func makeContext(
    conversations: any ConversationManaging,
    project: (any ProjectProviding)? = nil,
    chat: (any ChatSectionProviding)? = nil
) -> ConversationListContext {
    ConversationListContext(
        conversations: conversations,
        project: project,
        agentTurn: nil,
        conversationState: nil,
        chat: chat
    )
}
