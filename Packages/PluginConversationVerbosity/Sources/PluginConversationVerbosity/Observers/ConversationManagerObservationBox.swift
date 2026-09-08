import Foundation
import SwiftUI
import ProviderConversation

/// Bridges conversation-manager changes to SwiftUI for the toolbar.
@MainActor
final class ConversationManagerObservationBox: ObservableObject {
    let capability: any ConversationVerbosityCapability
    @Published private(set) var revision = 0
    private var handle: (any ConversationObserverHandle)?

    init(capability: any ConversationVerbosityCapability) {
        self.capability = capability
        handle = capability.addConversationObserver { [weak self] event in
            // Refresh UI on verbosity changes, selection changes, or structural changes.
            switch event {
            case .verbosityChanged, .selected, .created, .deleted, .listChanged:
                self?.revision += 1
            default:
                break
            }
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}
