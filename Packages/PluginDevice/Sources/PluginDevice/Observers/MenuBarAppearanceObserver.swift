import AppKit
import Combine
import Foundation

/// Observes menu-bar appearance broadcasts and refreshes the rendered snapshot.
@MainActor
final class MenuBarAppearanceObserver {
    private var cancellable: AnyCancellable?

    init(onChange: @escaping (NSStatusBarButton?) -> Void) {
        cancellable = NotificationCenter.default.publisher(for: .lumiMenuBarAppearanceDidChange)
            .receive(on: RunLoop.main)
            .sink { notification in
                onChange(notification.object as? NSStatusBarButton)
            }
    }

    func cancel() {
        cancellable?.cancel()
        cancellable = nil
    }
}
