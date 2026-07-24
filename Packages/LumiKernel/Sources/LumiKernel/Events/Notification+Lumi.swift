import Foundation

public extension Notification.Name {
    /// Posted when the set of enabled plugins changes.
    /// Subscribers (MenuBar, LumiUI, EditorCoreService, etc.) use this to refresh their state.
    static let lumiEnabledPluginsDidChange = Notification.Name("com.coffic.lumi.enabledPluginsDidChange")
}

/// Convenience helper for subscribing to enabled-plugins-changed events.
public extension NotificationCenter {
    /// Subscribe to `.lumiEnabledPluginsDidChange`.
    /// Returns an opaque observer token that must be passed to `removeObserver(_:)` in `deinit`.
    @MainActor
    func onLumiEnabledPluginsDidChange(_ handler: @escaping () -> Void) -> NSObjectProtocol {
        addObserver(forName: .lumiEnabledPluginsDidChange, object: nil, queue: .main) { _ in
            handler()
        }
    }
}
