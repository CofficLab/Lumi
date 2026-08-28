import AppKit
import Foundation
import KernelCore
import ProviderCommand
import ProviderStorage

/// `CommandProviding` 的默认实现。
///
/// 管理命令的注册、注销和查询。
@MainActor
public final class CommandManager: CommandProviding {
    @Published public private(set) var allCommandGroups: [CommandMenuGroup] = []
    private var observers: [WeakObserver] = []

    public init() {}

    public func registerCommandGroup(_ group: CommandMenuGroup) {
        if let index = allCommandGroups.firstIndex(where: { $0.id == group.id }) {
            allCommandGroups[index] = group
        } else {
            allCommandGroups.append(group)
        }
        notify(.groupsChanged)
    }

    public func unregisterCommandGroup(id: String) {
        let oldCount = allCommandGroups.count
        allCommandGroups.removeAll { $0.id == id }
        if allCommandGroups.count != oldCount {
            notify(.groupsChanged)
        }
    }

    @discardableResult
    public func addObserver(_ callback: @escaping (CommandProvidingEvent) -> Void) -> any CommandProvidingObserverHandle {
        let observer = Observer(owner: self, callback: callback)
        observers.append(WeakObserver(observer))
        return observer
    }

    private func remove(_ observer: Observer) {
        observers.removeAll { $0.observer === observer }
    }

    private func notify(_ event: CommandProvidingEvent) {
        observers.removeAll { $0.observer == nil }
        for observer in observers {
            observer.observer?.invoke(event)
        }
    }

    private final class Observer: CommandProvidingObserverHandle {
        private weak var owner: CommandManager?
        private let callback: (CommandProvidingEvent) -> Void
        private var cancelled = false

        init(owner: CommandManager, callback: @escaping (CommandProvidingEvent) -> Void) {
            self.owner = owner
            self.callback = callback
        }

        func cancel() {
            guard !cancelled else { return }
            cancelled = true
            owner?.remove(self)
        }

        func invoke(_ event: CommandProvidingEvent) {
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
