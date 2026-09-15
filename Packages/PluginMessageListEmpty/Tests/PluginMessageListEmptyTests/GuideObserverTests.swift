import Foundation
import ProviderChatSection
import ProviderProject
import ProviderToolbar
import Testing
@testable import PluginMessageListEmpty

@Test @MainActor func guideStateTracksContextSelectionProjectsAndSuggestionChanges() async throws {
    let project = DefaultProjectProvider()
    let toolbar = DefaultToolbarProviding()
    let coordinator = NoConversationSelectedToolbarCoordinator(project: project, toolbar: toolbar)
    let state = MessageListGuideState(
        context: .defaultChat,
        project: project,
        toolbarCoordinator: coordinator
    )

    #expect(state.context == .defaultChat)
    #expect(state.selectedConversationID == nil)
    #expect(state.currentProject == nil)
    #expect(state.projects.isEmpty)
    #expect(state.promptSuggestionsRevision == 0)

    state.handleContextChange(nil)
    let selectedID = UUID()
    state.handleSelectionChange(selectedID)
    state.handlePromptSuggestionsChange()
    state.handlePromptSuggestionsChange()
    coordinator.activate()
    #expect(!toolbar.visibleCategories.contains(.project))

    try await project.openProject(at: "/workspace/Project")
    state.handleProjectChange(project)

    #expect(state.context == nil)
    #expect(state.selectedConversationID == selectedID)
    #expect(state.currentProject?.path == "/workspace/Project")
    #expect(state.projects.map(\.path) == ["/workspace/Project"])
    #expect(state.promptSuggestionsRevision == 2)
    #expect(toolbar.visibleCategories.contains(.project))

    coordinator.deactivate()
    #expect(toolbar.visibleCategories.contains(.project))
}

@Test @MainActor func toolbarCoordinatorOnlyHidesProjectToolsWhileActiveAndNoProjectsExist() {
    let project = DefaultProjectProvider()
    let toolbar = DefaultToolbarProviding()
    toolbar.setHiddenCategories([.system], for: "another-plugin")
    let coordinator = NoConversationSelectedToolbarCoordinator(project: project, toolbar: toolbar)

    coordinator.refresh()
    #expect(toolbar.visibleCategories.contains(.project))

    coordinator.activate()
    #expect(!toolbar.visibleCategories.contains(.project))
    #expect(toolbar.visibleCategories.contains(.chat))
    #expect(!toolbar.visibleCategories.contains(.system))

    project.synchronizeProjects([ProjectInfo(name: "One", path: "/workspace/One")])
    coordinator.refresh()
    #expect(toolbar.visibleCategories.contains(.project))

    project.synchronizeProjects([])
    coordinator.refresh()
    #expect(!toolbar.visibleCategories.contains(.project))

    coordinator.deactivate()
    #expect(toolbar.visibleCategories.contains(.project))
    #expect(!toolbar.visibleCategories.contains(.system))
}
