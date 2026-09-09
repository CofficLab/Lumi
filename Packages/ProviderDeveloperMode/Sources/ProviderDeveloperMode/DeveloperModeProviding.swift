import Combine
import Foundation

/// Runtime switch for development-only UI and diagnostics.
@MainActor
public protocol DeveloperModeProviding: AnyObject, ObservableObject
    where ObjectWillChangePublisher == ObservableObjectPublisher {
    /// Whether development-only UI is currently enabled.
    var isEnabled: Bool { get }

    /// Changes the runtime developer-mode state.
    func setEnabled(_ enabled: Bool)

    /// Toggles the runtime developer-mode state.
    func toggle()
}

/// Default in-memory developer-mode provider.
@MainActor
public final class DefaultDeveloperModeProviding: DeveloperModeProviding, ObservableObject {
    @Published public private(set) var isEnabled: Bool

    public init(isEnabled: Bool = false) {
        self.isEnabled = isEnabled
    }

    public func setEnabled(_ enabled: Bool) {
        guard isEnabled != enabled else { return }
        isEnabled = enabled
    }

    public func toggle() {
        setEnabled(!isEnabled)
    }

}

/// SwiftUI-friendly projection of a developer-mode provider.
///
/// Consumers depend on the provider protocol while this object bridges its
/// `objectWillChange` publisher into local state for view invalidation.
@MainActor
public final class DeveloperModeObservation: ObservableObject {
    @Published public private(set) var isEnabled: Bool

    private var cancellable: AnyCancellable?

    public init(provider: (any DeveloperModeProviding)?) {
        self.isEnabled = provider?.isEnabled ?? false
        guard let provider else { return }
        cancellable = provider.objectWillChange.sink { [weak self, weak provider] _ in
            Task { @MainActor [weak self, weak provider] in
                guard let provider else { return }
                self?.isEnabled = provider.isEnabled
            }
        }
    }
}
