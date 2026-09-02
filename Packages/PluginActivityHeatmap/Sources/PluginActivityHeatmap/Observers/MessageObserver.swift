import Foundation
import ProviderMessage

/// Asks the activity heatmap model to reload after a message is inserted.
@MainActor
final class MessageObserver {
    private var handle: (any MessageInsertedObserverHandle)?

    init(messages: any MessageManaging, onInsert: @escaping () -> Void) {
        handle = messages.addMessageInsertedObserver { _, _ in
            onInsert()
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}
