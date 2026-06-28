import Foundation
import os
import SuperLogKit

public struct SemanticIndexMetricsSnapshot: Sendable, Equatable {
    public var cacheHits: Int
    public var cacheMisses: Int
    public var lastIndexDuration: TimeInterval?
    public var lastEntryCount: Int?
}

public enum SemanticIndexMetrics: SuperLog {
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "xcode.semantic-index")
    private static let lock = NSLock()
    private nonisolated(unsafe) static var cacheHits = 0
    private nonisolated(unsafe) static var cacheMisses = 0
    private nonisolated(unsafe) static var lastIndexDuration: TimeInterval?
    private nonisolated(unsafe) static var lastEntryCount: Int?

    public static func recordCacheHit(workspacePath: String, entryCount: Int?) {
        lock.lock()
        cacheHits += 1
        lastEntryCount = entryCount
        lock.unlock()
        logger.info("\(Self.t)semantic_index_cache_hit workspace=\(workspacePath, privacy: .public) entries=\(entryCount ?? 0)")
    }

    public static func recordCacheMiss(workspacePath: String, reason: String) {
        lock.lock()
        cacheMisses += 1
        lock.unlock()
        logger.info("\(Self.t)semantic_index_cache_miss workspace=\(workspacePath, privacy: .public) reason=\(reason, privacy: .public)")
    }

    public static func recordIndexCompleted(workspacePath: String, duration: TimeInterval, entryCount: Int) {
        lock.lock()
        lastIndexDuration = duration
        lastEntryCount = entryCount
        lock.unlock()
        logger.info("\(Self.t)semantic_index_complete workspace=\(workspacePath, privacy: .public) duration=\(duration, privacy: .public)s entries=\(entryCount)")
    }

    public static func snapshot() -> SemanticIndexMetricsSnapshot {
        lock.lock()
        defer { lock.unlock() }
        return SemanticIndexMetricsSnapshot(
            cacheHits: cacheHits,
            cacheMisses: cacheMisses,
            lastIndexDuration: lastIndexDuration,
            lastEntryCount: lastEntryCount
        )
    }
}
