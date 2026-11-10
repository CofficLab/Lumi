import AppKit
import Foundation

/// 系统唤醒事件的观察中枢。
///
/// `Timer` 在系统睡眠期间不推进，醒来后原本到期的提醒会被静默推迟。
/// 这里集中监听 `NSWorkspace.didWakeNotification`，把唤醒事件分发给所有
/// 关心它的提醒环境。
///
/// 三个提醒插件各自持有一个 environment，若各自注册观察者会重复回调；
/// 这里用一个共享的观察者把事件广播给全部订阅者。
@MainActor
public final class SystemWakeObserver {
    public static let shared = SystemWakeObserver()

    private var subscribers: [UUID: @MainActor () -> Void] = [:]
    private var workspaceObserver: (any NSObjectProtocol)?

    private init() {}

    /// 订阅系统唤醒事件。
    ///
    /// - Returns: 订阅标识，调用 `unsubscribe(_:)` 取消。
    @discardableResult
    public func subscribe(_ handler: @escaping @MainActor () -> Void) -> UUID {
        let id = UUID()
        subscribers[id] = handler
        startObservingIfNeeded()
        return id
    }

    /// 取消订阅。
    public func unsubscribe(_ id: UUID) {
        subscribers.removeValue(forKey: id)
        if subscribers.isEmpty {
            stopObserving()
        }
    }

    private func startObservingIfNeeded() {
        guard workspaceObserver == nil else { return }
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.notifySubscribers()
            }
        }
    }

    private func stopObserving() {
        guard let workspaceObserver else { return }
        NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver)
        self.workspaceObserver = nil
    }

    private func notifySubscribers() {
        for handler in subscribers.values {
            handler()
        }
    }
}
