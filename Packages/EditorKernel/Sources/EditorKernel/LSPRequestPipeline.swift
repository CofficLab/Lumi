import Foundation

public final class RequestGeneration: @unchecked Sendable {
    private let lock = NSLock()
    private var _generation: UInt64 = 0

    public init() {}

    public var generation: UInt64 {
        lock.lock(); defer { lock.unlock() }
        return _generation
    }

    @discardableResult
    public func next() -> UInt64 {
        lock.lock(); defer { lock.unlock() }
        _generation += 1
        return _generation
    }

    public func isCurrent(_ gen: UInt64) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return gen == _generation
    }

    public func reset() {
        lock.lock(); defer { lock.unlock() }
        _generation = 0
    }

    @discardableResult
    public func invalidate() -> UInt64 {
        lock.lock(); defer { lock.unlock() }
        _generation += 1
        return _generation
    }
}

public final class CancellationContext: @unchecked Sendable {
    private let lock = NSLock()
    private var _isCancelled: Bool = false

    public init() {}

    public var isCancelled: Bool {
        lock.lock(); defer { lock.unlock() }
        return _isCancelled
    }

    public func cancel() {
        lock.lock(); defer { lock.unlock() }
        _isCancelled = true
    }

    public func checkCancellation() throws {
        lock.lock(); defer { lock.unlock() }
        if _isCancelled {
            throw CancellationError()
        }
    }
}

public final class LSPRequestLifecycle: @unchecked Sendable {
    private let lock = NSLock()
    private var _generation: UInt64 = 0

    public init() {}

    public func run<T: Sendable>(
        operation: @Sendable @escaping () async throws -> T,
        apply: @MainActor @escaping (T) -> Void
    ) {
        let gen: UInt64
        lock.lock()
        _generation += 1
        gen = _generation
        lock.unlock()

        Task {
            do {
                let result = try await operation()
                await MainActor.run {
                    let isCurrent: Bool
                    self.lock.lock()
                    isCurrent = (gen == self._generation)
                    self.lock.unlock()
                    guard isCurrent else { return }
                    apply(result)
                }
            } catch {
            }
        }
    }

    public func reset() {
        lock.lock(); defer { lock.unlock() }
        _generation = 0
    }

    @discardableResult
    public func invalidate() -> UInt64 {
        lock.lock(); defer { lock.unlock() }
        _generation += 1
        return _generation
    }
}
