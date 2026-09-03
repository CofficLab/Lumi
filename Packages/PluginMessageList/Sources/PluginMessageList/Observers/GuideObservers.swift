import ProviderChatSection
import ProviderProject
import SwiftUI

/// View state for the MessageList guide, created and updated by the plugin.
///
/// The plugin owns every external subscription. This object only exposes the
/// resulting state to SwiftUI and never registers an observer itself.
@MainActor
final class MessageListGuideState: ObservableObject {
    @Published private(set) var context: ChatContext?
    @Published private(set) var currentProject: ProjectInfo?
    @Published private(set) var projects: [ProjectInfo] = []
    @Published private(set) var promptSuggestionsRevision = 0

    let toolbarCoordinator: NoConversationSelectedToolbarCoordinator

    init(
        context: ChatContext?,
        project: (any ProjectProviding)?,
        toolbarCoordinator: NoConversationSelectedToolbarCoordinator
    ) {
        self.context = context
        currentProject = project?.currentProject
        projects = project?.projects ?? []
        self.toolbarCoordinator = toolbarCoordinator
    }

    func handleContextChange(_ context: ChatContext?) {
        self.context = context
    }

    func handleProjectChange(_ project: (any ProjectProviding)?) {
        currentProject = project?.currentProject
        projects = project?.projects ?? []
        toolbarCoordinator.refresh()
    }

    func handlePromptSuggestionsChange() {
        promptSuggestionsRevision &+= 1
    }
}
