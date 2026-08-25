import Foundation
import ProviderMessageSender

@MainActor
final class PluginMessageSenderObserverHandle: MessageSenderObserverHandle {
    private var cancellation: (() -> Void)?

    init(cancellation: @escaping () -> Void) {
        self.cancellation = cancellation
    }

    func cancel() {
        cancellation?()
        cancellation = nil
    }
}
