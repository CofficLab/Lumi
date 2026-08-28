import Foundation

public final class WebFetchCache: @unchecked Sendable {
    public static let shared = WebFetchCache()

    private var store: [String: CachedContent] = [:]
    private let lock = NSLock()
    private let maxEntries: Int
    private let ttl: TimeInterval

    public init(maxEntries: Int = 50, ttl: TimeInterval = 15 * 60) {
        self.maxEntries = maxEntries
        self.ttl = ttl
    }

    public func get(_ key: String, now: Date = Date()) -> CachedContent? {
        lock.lock()
        defer { lock.unlock() }

        guard let cached = store[key] else { return nil }

        if now.timeIntervalSince(cached.fetchedAt) > ttl {
            store.removeValue(forKey: key)
            return nil
        }

        return cached
    }

    public func set(_ key: String, value: CachedContent, now: Date = Date()) {
        lock.lock()
        defer { lock.unlock() }

        for (cacheKey, cached) in store where now.timeIntervalSince(cached.fetchedAt) > ttl {
            store.removeValue(forKey: cacheKey)
        }

        if store.count >= maxEntries {
            let oldest = store.min { $0.value.fetchedAt < $1.value.fetchedAt }
            if let oldestKey = oldest?.key {
                store.removeValue(forKey: oldestKey)
            }
        }

        store[key] = value
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        store.removeAll()
    }
}

public struct CachedContent: Sendable, Equatable {
    public let content: String
    public let contentType: String
    public let statusCode: Int
    public let contentSize: Int
    public let duration: Double
    public let fetchedAt: Date

    public init(
        content: String,
        contentType: String,
        statusCode: Int,
        contentSize: Int,
        duration: Double,
        fetchedAt: Date
    ) {
        self.content = content
        self.contentType = contentType
        self.statusCode = statusCode
        self.contentSize = contentSize
        self.duration = duration
        self.fetchedAt = fetchedAt
    }
}
