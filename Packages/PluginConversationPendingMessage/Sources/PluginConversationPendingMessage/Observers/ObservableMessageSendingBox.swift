import Combine
import ProviderMessageSender
import SwiftUI

/// SwiftUI bridge for the type-erased message sending provider.
@MainActor
public final class ObservableMessageSendingBox: ObservableObject {
    public let sender: any MessageSendingProviding
    private var cancellable: AnyCancellable?

    public init(sender: any MessageSendingProviding) {
        self.sender = sender
        cancellable = sender.objectWillChange
            .map { _ in () }
            .eraseToAnyPublisher()
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
    }

    func cancel() {
        cancellable?.cancel()
        cancellable = nil
    }
}
