import AppKit
import Combine
import Foundation

/// Observes application activation and input-source changes for InputService.
@MainActor
final class InputEventObserver {
    private var cancellables = Set<AnyCancellable>()

    init(
        onApplicationActivation: @escaping (NSRunningApplication) -> Void,
        onInputSourceChange: @escaping () -> Void
    ) {
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didActivateApplicationNotification)
            .compactMap { notification -> NSRunningApplication? in
                notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            }
            .sink { app in onApplicationActivation(app) }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSTextInputContext.keyboardSelectionDidChangeNotification)
            .sink { _ in onInputSourceChange() }
            .store(in: &cancellables)
    }

    func cancel() {
        cancellables.removeAll()
    }
}
