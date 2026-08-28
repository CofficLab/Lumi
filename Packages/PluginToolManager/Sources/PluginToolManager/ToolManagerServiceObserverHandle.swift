import Foundation
import ProviderToolManager

@MainActor
final class ToolManagerServiceObserverHandle: ToolManagerObserverHandle {
    private var cancellation: (() -> Void)?

    init(cancellation: @escaping () -> Void) {
        self.cancellation = cancellation
    }

    func cancel() {
        cancellation?()
        cancellation = nil
    }
}
