import Foundation
import LumiCoreKit

/// Three-tier cache for App Store Connect REST JSON responses.
///
/// - L1: in-memory (`ConnectCache`, ~5 min)
/// - L2: plugin DB disk (`api-cache/`)
/// - Network: on miss or `networkOnly` fetch policy
final class ConnectAPICache: @unchecked Sendable {
    static let shared: ConnectAPICache = {
        let root = (lumiCorePluginDataDirectory(for: ConnectAPICacheConfiguration.pluginName)
            ?? lumiCoreFallbackDataRootDirectory.appendingPathComponent(ConnectAPICacheConfiguration.pluginName, isDirectory: true))
            .appendingPathComponent(ConnectAPICacheConfiguration.cacheDirectoryName, isDirectory: true)
        return ConnectAPICache(rootDirectory: root)
    }()

    private let memoryCache: ConnectCache
    /// Backing disk store. `package` so tests can seed/inspect entries directly
    /// when exercising `ConnectCacheInvalidator` without the policy resolver.
    package let diskStore: ConnectAPICacheDiskStore
    private let versionStateIndex: VersionStateIndex

    init(
        rootDirectory: URL,
        memoryCache: ConnectCache? = nil,
        diskStore: ConnectAPICacheDiskStore? = nil,
        versionStateIndex: VersionStateIndex? = nil
    ) {
        let indexesDirectory = rootDirectory.appendingPathComponent(
            ConnectAPICacheConfiguration.indexesDirectoryName,
            isDirectory: true
        )
        self.memoryCache = memoryCache ?? ConnectCache(
            ttl: ConnectAPICacheConfiguration.memoryTTL,
            maxEntries: ConnectAPICacheConfiguration.memoryMaxEntries
        )
        self.diskStore = diskStore ?? ConnectAPICacheDiskStore(rootDirectory: rootDirectory)
        self.versionStateIndex = versionStateIndex ?? VersionStateIndex(indexesDirectory: indexesDirectory)
    }

    func get(
        logicalKey: String,
        fetchPolicy: ConnectFetchPolicy,
        now: Date = Date()
    ) -> Data? {
        guard fetchPolicy == .cacheFirst else { return nil }

        if let memory = memoryCache.get(logicalKey, now: now) {
            return memory
        }

        if let disk = diskStore.read(logicalKey: logicalKey, now: now) {
            memoryCache.set(logicalKey, data: disk.data, now: now)
            return disk.data
        }

        return nil
    }

    func set(
        logicalKey: String,
        method: String,
        path: String,
        data: Data,
        now: Date = Date()
    ) {
        memoryCache.set(logicalKey, data: data, now: now)

        let policy = ConnectCachePolicyResolver.resolve(
            method: method,
            path: path,
            versionStateIndex: versionStateIndex
        )
        _ = diskStore.store(
            logicalKey: logicalKey,
            method: method,
            path: path,
            retention: policy.retention,
            tags: policy.tags,
            data: data,
            now: now
        )

        if let appID = extractAppID(fromVersionsListPath: path) {
            versionStateIndex.update(fromVersionsListResponse: data, appID: appID)
        }
    }

    func invalidate(tags: Set<ConnectCacheTag>) {
        guard !tags.isEmpty else { return }
        let removedKeys = diskStore.invalidate(tags: tags)
        removedKeys.forEach { memoryCache.remove($0) }
    }

    func invalidate(accountKey: String, where predicate: @escaping (ConnectAPICacheEntry) -> Bool) {
        diskStore.invalidate(accountKey: accountKey, where: predicate)
        memoryCache.invalidate { key in
            guard key.hasPrefix("\(accountKey)|") else { return false }
            return Self.memoryKeyMatches(key: key, predicate: predicate)
        }
    }

    func invalidateAfterMutation(
        method: String,
        path: String,
        body: Data?,
        accountKey: String
    ) {
        ConnectCacheInvalidator.invalidateAfterMutation(
            method: method,
            path: path,
            body: body,
            accountKey: accountKey,
            cache: self
        )
    }

    func pruneVersions(keepingVersionIDs: Set<String>, accountKey: String) {
        versionStateIndex.prune(keepingVersionIDs: keepingVersionIDs)
        diskStore.pruneVersions(keepingVersionIDs: keepingVersionIDs, accountKey: accountKey)
        memoryCache.invalidate { key in
            guard key.hasPrefix("\(accountKey)|") else { return false }
            for versionID in extractVersionIDs(fromMemoryKey: key) {
                if !keepingVersionIDs.contains(versionID) {
                    return true
                }
            }
            return false
        }
    }

    func clear() {
        memoryCache.clear()
        diskStore.clear()
        versionStateIndex.clear()
    }

    func diskUsage() -> ConnectAPICacheDiskUsage {
        diskStore.diskUsage()
    }

    func retention(forVersionID versionID: String) -> ConnectCacheRetention {
        versionStateIndex.retention(forVersionID: versionID)
    }

    private func extractAppID(fromVersionsListPath path: String) -> String? {
        let prefix = "/v1/apps/"
        let suffix = "/appStoreVersions"
        guard path.hasPrefix(prefix), path.hasSuffix(suffix) else { return nil }
        let appID = String(path.dropFirst(prefix.count).dropLast(suffix.count))
        return appID.isEmpty ? nil : appID
    }

    private static func memoryKeyMatches(
        key: String,
        predicate: (ConnectAPICacheEntry) -> Bool
    ) -> Bool {
        let parts = key.split(separator: "|", maxSplits: 3, omittingEmptySubsequences: false)
        guard parts.count >= 3 else { return false }
        let method = String(parts[1])
        let path = String(parts[2])
        let synthetic = ConnectAPICacheEntry(
            key: key,
            objectName: "",
            method: method,
            path: path,
            retention: .standard,
            byteCount: 0,
            fetchedAt: .distantPast,
            lastAccess: .distantPast,
            tags: []
        )
        return predicate(synthetic)
    }

    private func extractVersionIDs(fromMemoryKey key: String) -> [String] {
        let parts = key.split(separator: "|", maxSplits: 3, omittingEmptySubsequences: false)
        guard parts.count >= 3 else { return [] }
        let path = String(parts[2])
        let prefix = "/v1/appStoreVersions/"
        guard path.hasPrefix(prefix) else { return [] }
        let remainder = path.dropFirst(prefix.count)
        guard let versionID = remainder.split(separator: "/").first else { return [] }
        return [String(versionID)]
    }
}
