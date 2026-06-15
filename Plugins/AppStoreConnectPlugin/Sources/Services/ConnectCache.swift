import Foundation

enum ConnectFetchPolicy: Sendable {
    case cacheFirst
    case networkOnly
}

final class ConnectCache: @unchecked Sendable {
    static let shared = ConnectCache()

    private struct Entry {
        let data: Data
        let fetchedAt: Date
    }

    private var store: [String: Entry] = [:]
    private let lock = NSLock()
    private let ttl: TimeInterval
    private let maxEntries: Int

    init(ttl: TimeInterval = 5 * 60, maxEntries: Int = 64) {
        self.ttl = ttl
        self.maxEntries = maxEntries
    }

    func get(_ key: String, now: Date = Date()) -> Data? {
        lock.lock()
        defer { lock.unlock() }

        purgeExpired(now: now)

        guard let entry = store[key] else { return nil }
        guard now.timeIntervalSince(entry.fetchedAt) <= ttl else {
            store.removeValue(forKey: key)
            return nil
        }
        return entry.data
    }

    func set(_ key: String, data: Data, now: Date = Date()) {
        lock.lock()
        defer { lock.unlock() }

        purgeExpired(now: now)

        if store.count >= maxEntries {
            let oldestKey = store.min { $0.value.fetchedAt < $1.value.fetchedAt }?.key
            if let oldestKey {
                store.removeValue(forKey: oldestKey)
            }
        }

        store[key] = Entry(data: data, fetchedAt: now)
    }

    func invalidate(where predicate: (String) -> Bool) {
        lock.lock()
        defer { lock.unlock() }
        store = store.filter { !predicate($0.key) }
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        store.removeAll()
    }

    private func purgeExpired(now: Date) {
        for (key, entry) in store where now.timeIntervalSince(entry.fetchedAt) > ttl {
            store.removeValue(forKey: key)
        }
    }
}
