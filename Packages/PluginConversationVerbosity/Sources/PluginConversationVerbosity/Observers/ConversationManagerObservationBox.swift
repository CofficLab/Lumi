import Combine
import SwiftUI

/// Bridges conversation-manager changes to SwiftUI for the toolbar.
@MainActor
final class ConversationManagerObservationBox: ObservableObject {
    let capability: any ConversationVerbosityCapability
    @Published private(set) var revision = 0
    private var cancellable: AnyCancellable?

    init(capability: any ConversationVerbosityCapability) {
        self.capability = capability
        cancellable = capability.objectWillChange
            .map { _ in () }
            .eraseToAnyPublisher()
            .sink { [weak self] _ in
                self?.revision += 1
            }
    }

    func cancel() {
        cancellable?.cancel()
        cancellable = nil
    }
}
