import Foundation
import os
import SuperLogKit

/// Global resource limits for semantic indexing workloads.
public enum SemanticIndexResourceManager: SuperLog {
    nonisolated(unsafe) static var verbose: Bool = false

    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "xcode.semantic-index.resources")
    private static let lock = NSLock()
    private nonisolated(unsafe) static var activeXcodebuildJobs = 0
    private nonisolated(unsafe) static var activeJobPriority: SemanticIndexJobPriority = .preload
    private nonisolated(unsafe) static var lastAccessByWorkspaceHash: [String: Date] = [:]
    private nonisolated(unsafe) static var cachedTotalBytes: Int64 = 0
    private nonisolated(unsafe) static var cachedTotalMeasuredAt: Date?

    public nonisolated(unsafe) static var maxConcurrentXcodebuildJobs = 1
    public nonisolated(unsafe) static var maxStoreBytes: Int64 = 20 * 1024 * 1024 * 1024
    public nonisolated(unsafe) static var directorySizeCacheTTL: TimeInterval = 300

    public static func acquireXcodebuildSlot(priority: SemanticIndexJobPriority = .activeWorkspace) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if activeXcodebuildJobs >= maxConcurrentXcodebuildJobs {
            if priority == .preload { return false }
            if activeJobPriority == .activeWorkspace { return false }
        }
        activeXcodebuildJobs += 1
        activeJobPriority = priority
        return true
    }

    public static func releaseXcodebuildSlot() {
        lock.lock()
        activeXcodebuildJobs = max(0, activeXcodebuildJobs - 1)
        if activeXcodebuildJobs == 0 {
            activeJobPriority = .preload
        }
        lock.unlock()
    }

    public static func markWorkspaceAccessed(_ workspacePath: String) {
        lock.lock()
        lastAccessByWorkspaceHash[workspacePath.md5Hash] = Date()
        lock.unlock()
    }

    public static func enforceDiskQuotaAsync(in pluginDirectory: URL) async -> Int {
        await Task.detached(priority: .utility) {
            enforceDiskQuota(in: pluginDirectory)
        }.value
    }

    @discardableResult
    public static func enforceDiskQuota(in pluginDirectory: URL) -> Int {
        let size = measuredDirectorySize(pluginDirectory)
        guard size > maxStoreBytes else { return 0 }
        let entries = (try? FileManager.default.contentsOfDirectory(
            at: pluginDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        let sorted = entries.compactMap { url -> (URL, Date)? in
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { return nil }
            let hash = url.lastPathComponent
            let accessed = lastAccessByWorkspaceHash[hash] ?? .distantPast
            return (url, accessed)
        }.sorted { $0.1 < $1.1 }

        var removed = 0
        var remaining = size
        for (url, _) in sorted where remaining > maxStoreBytes {
            let derivedData = url.appendingPathComponent("DerivedData", isDirectory: true)
            if FileManager.default.fileExists(atPath: derivedData.path) {
                try? FileManager.default.removeItem(at: derivedData)
                remaining -= directorySize(derivedData)
                removed += 1
                if Self.verbose {
                    logger.info("\(Self.t)LRU removed DerivedData for \(url.lastPathComponent, privacy: .public)")
                }
            }
        }
        lock.lock()
        cachedTotalBytes = remaining
        cachedTotalMeasuredAt = Date()
        lock.unlock()
        return removed
    }

    private static func measuredDirectorySize(_ url: URL) -> Int64 {
        lock.lock()
        if let measuredAt = cachedTotalMeasuredAt,
           Date().timeIntervalSince(measuredAt) < directorySizeCacheTTL,
           cachedTotalBytes < Int64(Double(maxStoreBytes) * 0.8) {
            let cached = cachedTotalBytes
            lock.unlock()
            return cached
        }
        lock.unlock()
        let size = directorySize(url)
        lock.lock()
        cachedTotalBytes = size
        cachedTotalMeasuredAt = Date()
        lock.unlock()
        return size
    }

    static func directorySize(_ url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            total += Int64(size)
        }
        return total
    }
}
