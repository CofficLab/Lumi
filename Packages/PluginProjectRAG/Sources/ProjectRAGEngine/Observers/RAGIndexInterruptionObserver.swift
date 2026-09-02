import AppKit
import Foundation

/// Observes foreground activation and interrupts background indexing.
@MainActor
final class RAGIndexInterruptionObserver {
    private var token: NSObjectProtocol?

    init(onInterrupt: @escaping @MainActor () async -> Void) {
        token = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                await onInterrupt()
            }
        }
    }

    func cancel() {
        if let token {
            NotificationCenter.default.removeObserver(token)
            self.token = nil
        }
    }
}
