import Foundation

/// Minimal stub for legacy editor views that still expect a conversation VM on the environment.
@MainActor
public final class WindowConversationVM: ObservableObject {
    public let windowId: UUID?

    public init(windowId: UUID? = nil) {
        self.windowId = windowId
    }
}
