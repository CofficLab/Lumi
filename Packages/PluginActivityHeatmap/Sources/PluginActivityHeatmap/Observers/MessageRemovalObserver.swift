import Foundation
import ProviderMessage

/// Asks the activity heatmap model to refresh after messages are deleted or a
/// conversation is cleared (#238). Both events carry only a message or
/// conversation ID, so the model invalidates its whole historical cache
/// instead of recomputing a single date. Insertions and streaming updates are
/// handled by ``MessageObserver`` and must not trigger an invalidation.
@MainActor
final class MessageRemovalObserver {
    private var handle: (any MessageChangeObserverHandle)?

    init(messages: any MessageManaging, onRemoval: @escaping () -> Void) {
        handle = messages.addMessageChangeObserver { change in
            switch change {
            case .deleted, .cleared:
                onRemoval()
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
