import Foundation

/// Observes goal-change notifications emitted by Goal Task tools.
@MainActor
final class GoalChangeObserver {
    private var token: NSObjectProtocol?

    init(onChange: @escaping (Notification) -> Void) {
        token = NotificationCenter.default.addObserver(
            forName: .goalDidChange,
            object: nil,
            queue: .main
        ) { notification in
            onChange(notification)
        }
    }

    func cancel() {
        if let token {
            NotificationCenter.default.removeObserver(token)
            self.token = nil
        }
    }
}
