import AppKit
import Combine

/// Platform-event ingress for Computer Use. The plugin entry point owns this
/// observer; settings views only consume the typed revision it produces.
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
final class ComputerUseSettingsState: ObservableObject {
    @Published private(set) var revision = 0

    func refresh() {
        revision &+= 1
    }
}
