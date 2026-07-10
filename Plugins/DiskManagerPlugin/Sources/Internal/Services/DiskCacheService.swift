import Foundation
import os

// MARK: - Cache Model

public struct ScanCache: Codable {
    public let path: String
    public let entries: [DirectoryEntry]
    public let largeFiles: [LargeFileEntry]
    public let timestamp: Date
    public let totalSize: Int64
    public let totalFiles: Int

    public var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > 3600
    }
}

// MARK: - Cache Service

public actor ScanCacheService {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.disk-cache")

    public static let shared = ScanCacheService()

    private let cacheDirectory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        self.cacheDirectory = Self.defaultCacheDirectory(
            cachesDirectory: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first,
            temporaryDirectory: FileManager.default.temporaryDirectory
        )
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    public init(cacheDirectory: URL) {
        self.cacheDirectory = cacheDirectory
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    static func defaultCacheDirectory(cachesDirectory: URL?, temporaryDirectory: URL) -> URL {
        let base = cachesDirectory ?? temporaryDirectory
        return base.appendingPathComponent("DiskManagerKit/ScanCache", isDirectory: true)
    }

    public func save(_ result: ScanResult, for path: String) {
        let cache = ScanCache(
            path: path,
            entries: result.entries,
            largeFiles: result.largeFiles,
            timestamp: result.scannedAt,
            totalSize: result.totalSize,
            totalFiles: result.totalFiles
        )

        let fileURL = cacheFileURL(for: path)

        Task.detached(priority: .background) {
            do {
                let data = try JSONEncoder().encode(cache)
                try data.write(to: fileURL)
            } catch {
                Self.logger.error("Failed to save scan cache: \(error.localizedDescription)")
            }
        }
    }

    public func load(for path: String) -> ScanResult? {
        let fileURL = cacheFileURL(for: path)

        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }

        do {
            let data = try Data(contentsOf: fileURL)
            let cache = try JSONDecoder().decode(ScanCache.self, from: data)

            if cache.isExpired {
                try? FileManager.default.removeItem(at: fileURL)
                return nil
            }

            return ScanResult(
                entries: cache.entries,
                largeFiles: cache.largeFiles,
                totalSize: cache.totalSize,
                totalFiles: cache.totalFiles,
                scanDuration: 0,
                scannedAt: cache.timestamp
            )
        } catch {
            return nil
        }
    }

    public func clearCache() {
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    private func cacheFileURL(for path: String) -> URL {
        let safeName = path.data(using: .utf8)?.base64EncodedString() ?? "unknown"
        return cacheDirectory.appendingPathComponent("\(safeName).json")
    }
}
