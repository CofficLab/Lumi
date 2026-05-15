import Foundation

public extension LumiPreviewFacade {
/// Small LRU cache keyed by standardized source file paths.
struct PreviewFileContextCache<Context> {
    private var contexts: [String: Context] = [:]
    private var recency: [String] = []
    private let maximumCount: Int

    public init(maximumCount: Int) {
        self.maximumCount = max(0, maximumCount)
    }

    public var count: Int {
        contexts.count
    }

    public var keysInLeastRecentOrder: [String] {
        recency
    }

    public static func key(for fileURL: URL) -> String {
        fileURL.standardizedFileURL.resolvingSymlinksInPath().path
    }

    public mutating func value(forKey key: String) -> Context? {
        contexts[key]
    }

    public mutating func value(for fileURL: URL) -> Context? {
        value(forKey: Self.key(for: fileURL))
    }

    @discardableResult
    public mutating func removeValue(forKey key: String) -> Context? {
        removeRecency(key)
        return contexts.removeValue(forKey: key)
    }

    @discardableResult
    public mutating func removeValue(for fileURL: URL) -> Context? {
        removeValue(forKey: Self.key(for: fileURL))
    }

    /// Removes every cached context and returns them in least-recently-used order.
    @discardableResult
    public mutating func removeAll() -> [(key: String, value: Context)] {
        let removed = recency.compactMap { key -> (key: String, value: Context)? in
            guard let value = contexts[key] else { return nil }
            return (key, value)
        }
        contexts.removeAll()
        recency.removeAll()
        return removed
    }

    /// Stores a context and returns contexts evicted because of the maximum size.
    @discardableResult
    public mutating func store(_ context: Context, forKey key: String) -> [(key: String, value: Context)] {
        guard maximumCount > 0 else {
            let existing = contexts.removeValue(forKey: key).map { [(key: key, value: $0)] } ?? []
            removeRecency(key)
            return existing
        }

        contexts[key] = context
        markRecentlyUsed(key)
        return prune()
    }

    @discardableResult
    public mutating func store(_ context: Context, for fileURL: URL) -> [(key: String, value: Context)] {
        store(context, forKey: Self.key(for: fileURL))
    }

    public mutating func markRecentlyUsed(_ key: String) {
        removeRecency(key)
        recency.append(key)
    }

    private mutating func removeRecency(_ key: String) {
        recency.removeAll { $0 == key }
    }

    private mutating func prune() -> [(key: String, value: Context)] {
        var removed: [(key: String, value: Context)] = []
        while recency.count > maximumCount {
            let removedKey = recency.removeFirst()
            if let context = contexts.removeValue(forKey: removedKey) {
                removed.append((key: removedKey, value: context))
            }
        }
        return removed
    }
}

}
