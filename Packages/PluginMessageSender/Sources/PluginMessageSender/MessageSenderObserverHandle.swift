import Foundation
import ProviderMessageSender

@MainActor
final class MessageSenderObserverHandleImpl: MessageSenderObserverHandle {
    private var cancellation: (() -> Void)?

    init(cancellation: @escaping () -> Void) {
        self.cancellation = cancellation
    }

    func cancel() {
        cancellation?()
        cancellation = nil
    }
}
