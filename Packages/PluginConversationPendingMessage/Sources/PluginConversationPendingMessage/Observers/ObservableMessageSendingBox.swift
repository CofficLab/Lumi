import ProviderMessageSender
import SwiftUI

/// SwiftUI bridge for the type-erased message sending provider.
@MainActor
public final class ObservableMessageSendingBox: ObservableObject {
    public let sender: any MessageSendingProviding
    private var observer: (any MessageSenderObserverHandle)?

    public init(sender: any MessageSendingProviding) {
        self.sender = sender
        observer = sender.addMessageSenderObserver { [weak self] event in
            switch event {
            case .pendingMessagesChanged:
                self?.objectWillChange.send()
            case .started, .turnCompleted, .turnFailed, .attachmentsChanged:
                break
            }
        }
    }

    func cancel() {
        observer?.cancel()
        observer = nil
    }
}
