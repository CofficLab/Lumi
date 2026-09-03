import AppKit
import Combine

/// Platform-event ingress for Screen Recorder. Its lifecycle is owned by the
/// plugin entry point, not by the settings view.
@MainActor
final class ApplicationActivationObserver {
    private var token: NSObjectProtocol?

    init(onActivate: @escaping () -> Void) {
        token = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in onActivate() }
    }

    func cancel() {
        if let token {
            NotificationCenter.default.removeObserver(token)
            self.token = nil
        }
    }
}

@MainActor
final class ScreenRecorderSettingsState: ObservableObject {
    @Published private(set) var revision = 0

    func refresh() {
        revision &+= 1
    }
}
