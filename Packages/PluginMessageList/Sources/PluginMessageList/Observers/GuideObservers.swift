import Combine
import ProviderChatSection
import ProviderPromptSuggestion
import ProviderProject
import SwiftUI
import ProviderToolbar

@MainActor
final class PromptSuggestionsObserver: ObservableObject {
    private var cancellable: AnyCancellable?
    init(provider: (any PromptSuggestionProviding)?) {
        cancellable = provider?.changes.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }
}

@MainActor
final class ProjectObserver: ObservableObject {
    let project: (any ProjectProviding)?
    private var projectObserver: (any ProjectProvidingObserverHandle)?
    init(project: (any ProjectProviding)?) {
        self.project = project
        projectObserver = project?.addObserver { [weak self] _ in self?.objectWillChange.send() }
    }
}

@MainActor
final class ChatContextObserver: ObservableObject {
    @Published private(set) var context: ChatContext?
    private var observer: (any ChatSectionProvidingObserverHandle)?

    init(chat: (any ChatSectionProviding)?) {
        context = chat?.activeContext
        observer = chat?.addObserver { [weak self] event in
            guard case let .activeContextChanged(context) = event else { return }
            self?.context = context
        }
    }

}

/// Aggregates the observers shared by the message-list empty states.
@MainActor
final class MessageListGuideState: ObservableObject {
    let promptObserver: PromptSuggestionsObserver
    let contextObserver: ChatContextObserver
    let projectObserver: ProjectObserver
    let toolbarCoordinator: NoConversationSelectedToolbarCoordinator
    private var cancellables = Set<AnyCancellable>()

    init(
        promptObserver: PromptSuggestionsObserver,
        contextObserver: ChatContextObserver,
        projectObserver: ProjectObserver,
        toolbarCoordinator: NoConversationSelectedToolbarCoordinator
    ) {
        self.promptObserver = promptObserver
        self.contextObserver = contextObserver
        self.projectObserver = projectObserver
        self.toolbarCoordinator = toolbarCoordinator
        [promptObserver.objectWillChange, contextObserver.objectWillChange, projectObserver.objectWillChange]
            .forEach { publisher in
                publisher.sink { [weak self] in
                    self?.objectWillChange.send()
                }
                .store(in: &cancellables)
            }
    }

    var context: ChatContext? { contextObserver.context }
    var currentProject: ProjectInfo? { projectObserver.project?.currentProject }
}
