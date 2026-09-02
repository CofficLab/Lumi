import Foundation

/// Observes store-change broadcasts emitted by Story Writer tools.
@MainActor
final class StoryWriterChangeObserver {
    private var token: NSObjectProtocol?

    init(onChange: @escaping () -> Void) {
        token = NotificationCenter.default.addObserver(
            forName: .storyWriterDidChange,
            object: nil,
            queue: .main
        ) { _ in onChange() }
    }

    func cancel() {
        if let token {
            NotificationCenter.default.removeObserver(token)
            self.token = nil
        }
    }
}
