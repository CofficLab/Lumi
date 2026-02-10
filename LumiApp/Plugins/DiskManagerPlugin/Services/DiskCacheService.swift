import Foundation
import OSLog
import MagicKit

// MARK: - 缓存模型

struct ScanCache: Codable {
    let path: String
    let entries: [DirectoryEntry]
    let largeFiles: [LargeFileEntry]
    let timestamp: Date
    let totalSize: Int64
    let totalFiles: Int
    
    // 简单校验：1小时过期
    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > 3600
    }
}

// MARK: - 缓存服务

actor ScanCacheService: SuperLog {
    static let shared = ScanCacheService()
    
    private let cacheDirectory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    init() {
        // 使用 App 的 Caches 目录
        let cacheBase = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.cacheDirectory = cacheBase.appendingPathComponent("DiskManagerPlugin/ScanCache")
        
        // 确保目录存在
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    func save(_ result: ScanResult, for path: String) {
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
                // os_log("Cached scan result for \(path)")
            } catch {
                // os_log(.error, "Failed to cache scan result: \(error)")
            }
        }
    }
    
    func load(for path: String) -> ScanResult? {
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
                scanDuration: 0, // Cached, unknown original duration
                scannedAt: cache.timestamp
            )
        } catch {
            return nil
        }
    }
    
    func clearCache() {
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    private func cacheFileURL(for path: String) -> URL {
        // 使用 path 的 hash 或 base64 作为文件名
        let safeName = path.data(using: .utf8)?.base64EncodedString() ?? "unknown"
        return cacheDirectory.appendingPathComponent("\(safeName).json")
    }
}
