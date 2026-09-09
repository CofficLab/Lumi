import Foundation

/// Developer-mode state change event.
@MainActor
public enum DeveloperModeProvidingEvent {
    case enabledChanged(Bool)
}

/// Developer-mode state observation handle.
@MainActor
public protocol DeveloperModeProvidingObserverHandle: AnyObject {
    func cancel()
}

@MainActor
public final class NoopDeveloperModeProvidingObserverHandle: DeveloperModeProvidingObserverHandle {
    public init() {}
    public func cancel() {}
}

/// Runtime switch for development-only UI and diagnostics.
@MainActor
public protocol DeveloperModeProviding: AnyObject {
    /// Whether development-only UI is currently enabled.
    var isEnabled: Bool { get }

    /// Changes the runtime developer-mode state.
    func setEnabled(_ enabled: Bool)

    /// Toggles the runtime developer-mode state.
    func toggle()

    /// Registers an observer for semantic state changes.
    @discardableResult
    func addObserver(_ callback: @escaping (DeveloperModeProvidingEvent) -> Void) -> any DeveloperModeProvidingObserverHandle
}

/// Default in-memory developer-mode provider.
@MainActor
public final class DefaultDeveloperModeProviding: DeveloperModeProviding {
    public private(set) var isEnabled: Bool
    private var observers: [WeakObserver] = []

    public init(isEnabled: Bool = false) {
        self.isEnabled = isEnabled
    }

    public func setEnabled(_ enabled: Bool) {
        guard isEnabled != enabled else { return }
        isEnabled = enabled
        notify(.enabledChanged(enabled))
    }

    public func toggle() {
        setEnabled(!isEnabled)
    }

    @discardableResult
    public func addObserver(_ callback: @escaping (DeveloperModeProvidingEvent) -> Void) -> any DeveloperModeProvidingObserverHandle {
        let observer = Observer(owner: self, callback: callback)
        observers.append(WeakObserver(observer))
        return observer
    }

    private func remove(_ observer: Observer) {
        observers.removeAll { $0.observer === observer }
    }

    private func notify(_ event: DeveloperModeProvidingEvent) {
        observers.removeAll { $0.observer == nil }
        let activeObservers = observers
        for observer in activeObservers {
            observer.observer?.invoke(event)
        }
    }

    private final class Observer: DeveloperModeProvidingObserverHandle {
        private weak var owner: DefaultDeveloperModeProviding?
        private let callback: (DeveloperModeProvidingEvent) -> Void
        private var cancelled = false

        init(owner: DefaultDeveloperModeProviding, callback: @escaping (DeveloperModeProvidingEvent) -> Void) {
            self.owner = owner
            self.callback = callback
        }

        func cancel() {
            guard !cancelled else { return }
            cancelled = true
            owner?.remove(self)
        }

        func invoke(_ event: DeveloperModeProvidingEvent) {
            guard !cancelled else { return }
            callback(event)
        }
    }

    private final class WeakObserver {
        weak var observer: Observer?

        init(_ observer: Observer) {
            self.observer = observer
        }
    }
}
