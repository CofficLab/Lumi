import Foundation

// MARK: - Typed Observer (protocol level)

/// 开发者活动 / 休息窗口推断的语义变更事件。
///
/// 与其它 Providing 的 typed event 机制一致：消费者通过
/// `IdleTimeProviding.addObserver(_:)` 注册回调。回调为 `@Sendable`，
/// 可能在任意线程执行，消费方（通常是 UI）应在回调内自行 hop 到主线程。
public enum IdleTimeProvidingEvent {
    /// 推断快照刷新完成。回调时 `currentSnapshot()` 已可读到最新值。
    case snapshotChanged
}

/// 开发者活动观察句柄。
///
/// 在释放或显式调用 `cancel()` 后自动停止接收通知。
public protocol IdleTimeProvidingObserverHandle: AnyObject, Sendable {
    /// 停止接收后续变更通知。重复调用无副作用。
    func cancel()
}

/// 不需要语义事件实现的轻量 `IdleTimeProviding` 替身兼容句柄。
public final class NoopIdleTimeProvidingObserverHandle: IdleTimeProvidingObserverHandle, @unchecked Sendable {
    public init() {}
    public func cancel() {}
}

// MARK: - Backward-compatible snapshot change channel

/// Typed change channel for Idle Time snapshot updates.
///
/// The provider owns the source of the event; each plugin creates an observer
/// in its own `Observers` directory and owns that observer's lifecycle.
public final class IdleTimeSnapshotChangeCenter: @unchecked Sendable {
    public static let shared = IdleTimeSnapshotChangeCenter()

    private let lock = NSLock()
    private var callbacks: [UUID: @Sendable () -> Void] = [:]

    public init() {}

    @discardableResult
    public func addObserver(_ callback: @escaping @Sendable () -> Void) -> IdleTimeSnapshotChangeHandle {
        let id = UUID()
        lock.lock()
        callbacks[id] = callback
        lock.unlock()
        return IdleTimeSnapshotChangeHandle { [weak self] in
            self?.lock.lock()
            self?.callbacks[id] = nil
            self?.lock.unlock()
        }
    }

    public func notify() {
        lock.lock()
        let currentCallbacks = Array(callbacks.values)
        lock.unlock()
        currentCallbacks.forEach { $0() }
    }
}

public final class IdleTimeSnapshotChangeHandle: @unchecked Sendable {
    private var cancellation: (@Sendable () -> Void)?

    fileprivate init(cancellation: @escaping @Sendable () -> Void) {
        self.cancellation = cancellation
    }

    public func cancel() {
        cancellation?()
        cancellation = nil
    }
}
