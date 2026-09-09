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
