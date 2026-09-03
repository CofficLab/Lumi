import Combine
import Foundation

/// Plugin-owned change channel for HTTP exchange records.
///
/// Recording is performed from background URL loading paths, so the channel
/// is intentionally independent of the main actor and of NotificationCenter.
final class HTTPExchangeChangeCenter: @unchecked Sendable {
    static let shared = HTTPExchangeChangeCenter()

    private let lock = NSLock()
    private var callbacks: [UUID: @Sendable () -> Void] = [:]

    @discardableResult
    func addObserver(_ callback: @escaping @Sendable () -> Void) -> HTTPExchangeChangeHandle {
        let id = UUID()
        lock.lock()
        callbacks[id] = callback
        lock.unlock()

        return HTTPExchangeChangeHandle { [weak self] in
            self?.removeObserver(id: id)
        }
    }

    func notify() {
        lock.lock()
        let observers = Array(callbacks.values)
        lock.unlock()

        observers.forEach { $0() }
    }

    private func removeObserver(id: UUID) {
        lock.lock()
        callbacks.removeValue(forKey: id)
        lock.unlock()
    }
}

public final class HTTPExchangeChangeHandle: @unchecked Sendable {
    private let lock = NSLock()
    private var cancellation: (@Sendable () -> Void)?

    init(cancellation: @escaping @Sendable () -> Void) {
        self.cancellation = cancellation
    }

    public func cancel() {
        lock.lock()
        let cancellation = self.cancellation
        self.cancellation = nil
        lock.unlock()
        cancellation?()
    }

    deinit {
        cancel()
    }
}

@MainActor
final class HTTPExchangeObserver {
    private var handle: HTTPExchangeChangeHandle?

    init(store: HTTPExchangeStore, onChange: @escaping @Sendable () -> Void) {
        handle = store.addObserver(onChange)
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}

@MainActor
public final class HTTPExchangeSettingsState: ObservableObject {
    @Published private(set) var revision = 0

    public init() {}

    func refresh() {
        revision &+= 1
    }
}
