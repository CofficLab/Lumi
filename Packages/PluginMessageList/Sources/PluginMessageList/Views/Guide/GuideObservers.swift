import Combine
import ProviderProject
import SwiftUI

@MainActor
final class PromptSuggestionsObserver: ObservableObject {
    private var cancellable: AnyCancellable?
    init(services: MessageListServices) {
        cancellable = services.promptSuggestionsChangesPublisher.sink { [weak self] _ in self?.objectWillChange.send() }
    }
}

@MainActor
final class ProjectObserver: ObservableObject {
    let project: (any ProjectProviding)?
    private var cancellable: AnyCancellable?
    init(project: (any ProjectProviding)?) {
        self.project = project
        cancellable = project?.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
    }
}
