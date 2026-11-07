import Foundation
import ProviderTheme

/// Forwards theme-provider typed events to the theme settings page.
@MainActor
final class ThemeSettingsObservationModel {
    enum Event {
        case themeChanged(ThemeProvidingEvent)
    }

    protocol ObserverHandle: AnyObject {
        func cancel()
    }

    private final class Handle: ObserverHandle {
        private let cancelAction: () -> Void
        private var isCancelled = false

        init(cancelAction: @escaping () -> Void) {
            self.cancelAction = cancelAction
        }

        func cancel() {
            guard !isCancelled else { return }
            isCancelled = true
            cancelAction()
        }
    }

    private var handle: (any ThemeProvidingObserverHandle)?
    private var observers: [UUID: (Event) -> Void] = [:]

    init(theme: any ThemeProviding) {
        handle = theme.addObserver { [weak self] event in
            self?.notify(.themeChanged(event))
        }
    }

    @discardableResult
    func addObserver(_ callback: @escaping (Event) -> Void) -> any ObserverHandle {
        let id = UUID()
        observers[id] = callback
        return Handle { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
        observers.removeAll()
    }

    private func notify(_ event: Event) {
        for callback in Array(observers.values) {
            callback(event)
        }
    }
}
