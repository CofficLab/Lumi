import Combine
import SwiftUI

@MainActor
public final class DefaultMenuBarProviding: MenuBarProviding, ObservableObject {
    public private(set) var contentItems: [MenuBarContribution] = []
    public private(set) var popupItems: [MenuBarContribution] = []
    private var observers: [UUID: (MenuBarEvent) -> Void] = [:]

    public init() {}

    @discardableResult
    public func addMenuBarObserver(
        _ callback: @escaping (MenuBarEvent) -> Void
    ) -> any MenuBarObserverHandle {
        let id = UUID()
        observers[id] = callback
        return ObserverHandle { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }

    public func replaceContentItems(_ items: [MenuBarContribution]) {
        contentItems = Self.sorted(items)
        notify(.contentItemsChanged)
    }

    public func replacePopupItems(_ items: [MenuBarContribution]) {
        popupItems = Self.sorted(items)
        notify(.popupItemsChanged)
    }

    private static func sorted(_ items: [MenuBarContribution]) -> [MenuBarContribution] {
        items.sorted {
            if $0.order != $1.order { return $0.order < $1.order }
            return $0.id < $1.id
        }
    }

    private func notify(_ event: MenuBarEvent) {
        objectWillChange.send()
        Array(observers.values).forEach { $0(event) }
    }

    private final class ObserverHandle: MenuBarObserverHandle {
        private var cancellation: (() -> Void)?

        init(cancellation: @escaping () -> Void) {
            self.cancellation = cancellation
        }

        func cancel() {
            cancellation?()
            cancellation = nil
        }
    }
}
