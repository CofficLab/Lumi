import Foundation

struct HTTPExchangeDailyCountCacheSnapshot: Sendable {
    let counts: [String: Int]
    let versions: [String: Int]
}

/// Small, thread-safe persistence for daily HTTP exchange counts.
///
/// The cache deliberately stores only aggregate counts, never request or
/// response bodies. A per-day version lets a database write racing with a
/// chart read leave that day dirty instead of incorrectly accepting a stale
/// count as fresh.
final class HTTPExchangeDailyCountCache: @unchecked Sendable {
    private struct Payload: Codable {
        var counts: [String: Int]
        var dirtyKeys: Set<String>
    }

    private let url: URL
    private let lock = NSLock()
    private var counts: [String: Int] = [:]
    private var dirtyKeys: Set<String> = []
    private var versions: [String: Int] = [:]

    init(url: URL) {
        self.url = url
        load()
    }

    static func key(for day: Date) -> String {
        String(Int64(day.timeIntervalSince1970))
    }

    func snapshot(for keys: [String]) -> HTTPExchangeDailyCountCacheSnapshot {
        lock.lock()
        defer { lock.unlock() }

        var cleanCounts: [String: Int] = [:]
        var expectedVersions: [String: Int] = [:]
        for key in keys {
            expectedVersions[key] = versions[key, default: 0]
            if !dirtyKeys.contains(key), let count = counts[key] {
                cleanCounts[key] = count
            }
        }
        return HTTPExchangeDailyCountCacheSnapshot(
            counts: cleanCounts,
            versions: expectedVersions
        )
    }

    /// Stores counts only if the day was not invalidated since the read began.
    /// Returns the keys that were accepted; invalidated keys remain dirty.
    @discardableResult
    func store(
        _ refreshedCounts: [String: Int],
        expectedVersions: [String: Int],
        persist: Bool = true
    ) -> Set<String> {
        lock.lock()
        defer { lock.unlock() }

        var acceptedKeys: Set<String> = []
        for (key, count) in refreshedCounts {
            guard versions[key, default: 0] == expectedVersions[key, default: 0] else {
                continue
            }
            counts[key] = count
            dirtyKeys.remove(key)
            acceptedKeys.insert(key)
        }
        if persist, !acceptedKeys.isEmpty {
            persistLocked()
        }
        return acceptedKeys
    }

    /// Invalidates a single day. Normal writes keep this in memory because the
    /// current day is always refreshed and frequent requests should not cause
    /// a cache-file write for every exchange.
    func invalidate(dayKey: String, persist: Bool = false) {
        lock.lock()
        defer { lock.unlock() }

        versions[dayKey, default: 0] += 1
        dirtyKeys.insert(dayKey)
        if persist {
            persistLocked()
        }
    }

    /// Retention can remove records from any day when the record-count cap is
    /// reached, so all cached days must be considered stale after deletion.
    func invalidateAll(persist: Bool = true) {
        lock.lock()
        defer { lock.unlock() }

        let keys = Set(counts.keys).union(dirtyKeys)
        for key in keys {
            versions[key, default: 0] += 1
            dirtyKeys.insert(key)
        }
        if persist {
            persistLocked()
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            return
        }
        counts = payload.counts
        dirtyKeys = payload.dirtyKeys
    }

    private func persistLocked() {
        guard let data = try? JSONEncoder().encode(Payload(counts: counts, dirtyKeys: dirtyKeys)) else {
            return
        }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: url, options: .atomic)
    }
}
