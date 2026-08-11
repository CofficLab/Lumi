import Foundation

/// 轻量化的 `NotificationCenter` 观察者持有者。
///
/// 设计动机:`NSObjectProtocol` 观察者由 `NotificationCenter` 内部管理生命周期,
/// 但 Swift 的 `@MainActor` ViewModel 若直接持有 token 会因 actor 隔离产生
/// 编译问题。该 holder 以 `@unchecked Sendable` 包装,既允许跨 actor 传递,
/// 又在 `deinit` 中兜底移除,避免遗留观察者。
///
/// 标记 `internal` 是因为多个 ViewModel 共享同一份实现(`GoalVM`
/// 当前是唯一使用者,后续若有其他 ViewModel 接入通知也可复用)。
final class NotificationObserverHolder: @unchecked Sendable {
    private var observer: NSObjectProtocol?

    var hasObserver: Bool {
        observer != nil
    }

    deinit {
        remove()
    }

    func set(_ observer: NSObjectProtocol) {
        remove()
        self.observer = observer
    }

    func remove() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
    }
}