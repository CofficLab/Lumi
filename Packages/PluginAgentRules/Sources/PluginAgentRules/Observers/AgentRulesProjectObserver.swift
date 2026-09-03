import Foundation
import ProviderProject
import SwiftUI

/// Observes the project catalog used by the Agent Rules settings page.
@MainActor
public final class AgentRulesProjectObserver: ObservableObject {
    @Published private(set) var projects: [ProjectInfo] = []
    private var handle: (any ProjectProvidingObserverHandle)?

    public init(projectProvider: (any ProjectProviding)?) {
        guard let projectProvider else { return }
        projects = projectProvider.projects
        handle = projectProvider.addObserver { [weak self] event in
            guard case .projectsChanged(let projects) = event else { return }
            self?.projects = projects
        }
    }

    public func cancel() {
        handle?.cancel()
        handle = nil
    }

}
