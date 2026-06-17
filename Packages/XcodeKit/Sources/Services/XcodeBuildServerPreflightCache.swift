import Foundation

/// Caches expensive preflight checks (subprocess spawns) off the hot UI path.
public enum XcodeBuildServerPreflightCache {
    public nonisolated(unsafe) static var ttl: TimeInterval = 60

    private static let lock = NSLock()
    private nonisolated(unsafe) static var cached: XcodeBuildServerLocator.PreflightResult?
    private nonisolated(unsafe) static var fetchedAt: Date?
    private nonisolated(unsafe) static var cachedBundledPath: String?

    public static func runPreflight(forceRefresh: Bool = false) -> XcodeBuildServerLocator.PreflightResult {
        lock.lock()
        defer { lock.unlock() }
        if !forceRefresh,
           let cached,
           let fetchedAt,
           Date().timeIntervalSince(fetchedAt) < ttl,
           cachedBundledPath == XcodeBuildServerLocator.bundledToolPath {
            return cached
        }
        let result = XcodeBuildServerLocator.runPreflight()
        self.cached = result
        self.fetchedAt = Date()
        self.cachedBundledPath = XcodeBuildServerLocator.bundledToolPath
        return result
    }

    public static func invalidate() {
        lock.lock()
        cached = nil
        fetchedAt = nil
        lock.unlock()
    }
}
