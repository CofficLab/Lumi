import Foundation

public final class DocumentHighlightCache: @unchecked Sendable {
    public static let defaultCapacity = 32

    private let lock = NSLock()
    private var entries: [DocumentHighlightKey: DocumentHighlightSnapshot] = [:]
    private var accessOrder: [DocumentHighlightKey] = []
    private let capacity: Int

    public private(set) var highlightRevision: Int = 0

    public init(capacity: Int = DocumentHighlightCache.defaultCapacity) {
        self.capacity = max(1, capacity)
    }

    public func store(_ snapshot: DocumentHighlightSnapshot) {
        lock.lock()
        defer { lock.unlock() }

        guard snapshot.highlightRevision == highlightRevision else { return }

        entries[snapshot.key] = snapshot
        touch(snapshot.key)
        evictIfNeeded()
    }

    public func snapshot(for key: DocumentHighlightKey) -> DocumentHighlightSnapshot? {
        lock.lock()
        defer { lock.unlock() }

        guard let snapshot = entries[key], snapshot.highlightRevision == highlightRevision else {
            return nil
        }
        touch(key)
        return snapshot
    }

    public func invalidate(key: DocumentHighlightKey) {
        lock.lock()
        defer { lock.unlock() }
        entries.removeValue(forKey: key)
        accessOrder.removeAll { $0 == key }
    }

    public func invalidateAll() {
        lock.lock()
        defer { lock.unlock() }
        entries.removeAll()
        accessOrder.removeAll()
    }

    public func bumpHighlightRevision() {
        lock.lock()
        defer { lock.unlock() }
        highlightRevision += 1
        entries.removeAll()
        accessOrder.removeAll()
    }

    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return entries.count
    }

    private func touch(_ key: DocumentHighlightKey) {
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
    }

    private func evictIfNeeded() {
        while accessOrder.count > capacity {
            let evicted = accessOrder.removeFirst()
            entries.removeValue(forKey: evicted)
        }
    }
}
