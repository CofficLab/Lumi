import AppKit
import Foundation

/// Refreshes visible file-tree cells after the active window appearance syncs.
@MainActor
final class FileTreeAppearanceObserver {
    private var token: NSObjectProtocol?

    init(onChange: @escaping () -> Void) {
        token = NotificationCenter.default.addObserver(
            forName: .lumiThemeDidSyncWindowAppearances,
            object: nil,
            queue: .main
        ) { _ in
            onChange()
        }
    }

    func cancel() {
        if let token {
            NotificationCenter.default.removeObserver(token)
            self.token = nil
        }
    }
}
