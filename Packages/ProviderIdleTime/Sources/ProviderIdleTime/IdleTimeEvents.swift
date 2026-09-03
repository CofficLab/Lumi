import Foundation

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
