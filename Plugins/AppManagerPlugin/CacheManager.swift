import Foundation
import SwiftUI
import OSLog

/// 缓存项数据结构
struct AppCacheItem: Codable {
    let bundlePath: String
    let lastModified: TimeInterval
    let name: String
    let identifier: String?
    let version: String?
    let iconFileName: String?
    let size: Int64
}

/// 缓存统计信息
struct CacheStats {
    var hitCount: Int = 0
    var missCount: Int = 0
    var totalCount: Int { hitCount + missCount }
    var hitRate: Double {
        guard totalCount > 0 else { return 0 }
        return Double(hitCount) / Double(totalCount)
    }
}

/// 缓存管理器
class CacheManager {
    static let shared = CacheManager()
    private let logger = Logger(subsystem: "com.coffic.lumi", category: "AppCacheManager")
    
    private let cacheFileName = "app_cache.json"
    private var cache: [String: AppCacheItem] = [:]
    private let lock = NSLock()
    private let fileManager = FileManager.default
    
    private(set) var stats = CacheStats()
    
    private var cacheDirectory: URL? {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("com.coffic.lumi/AppManagerPlugin")
    }
    
    private var cacheFileURL: URL? {
        cacheDirectory?.appendingPathComponent(cacheFileName)
    }
    
    init() {
        createCacheDirectoryIfNeeded()
        loadCache()
    }
    
    private func createCacheDirectoryIfNeeded() {
        guard let cacheDirectory = cacheDirectory else { return }
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            do {
                try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            } catch {
                logger.error("无法创建缓存目录: \(error.localizedDescription)")
            }
        }
    }
    
    /// 加载缓存
    private func loadCache() {
        lock.lock()
        defer { lock.unlock() }
        
        guard let url = cacheFileURL,
              fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else {
            return
        }
        
        do {
            let decoder = JSONDecoder()
            cache = try decoder.decode([String: AppCacheItem].self, from: data)
            logger.info("缓存加载成功，共 \(self.cache.count) 条记录")
        } catch {
            logger.error("缓存加载失败: \(error.localizedDescription)")
            // 缓存损坏，重置
            cache = [:]
        }
    }
    
    /// 保存缓存
    func saveCache() {
        lock.lock()
        defer { lock.unlock() }
        
        guard let url = cacheFileURL else { return }
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(cache)
            try data.write(to: url, options: .atomic)
            logger.info("缓存保存成功")
        } catch {
            logger.error("缓存保存失败: \(error.localizedDescription)")
        }
    }
    
    /// 获取缓存的应用信息
    /// - Parameters:
    ///   - path: 应用路径
    ///   - currentModificationDate: 当前文件修改时间
    /// - Returns: 缓存项（如果有效）
    func getCachedApp(at path: String, currentModificationDate: Date) -> AppCacheItem? {
        lock.lock()
        defer { lock.unlock() }
        
        guard let item = cache[path] else {
            stats.missCount += 1
            return nil
        }
        
        // 验证时间戳（允许 1 秒内的误差）
        if abs(item.lastModified - currentModificationDate.timeIntervalSince1970) < 1.0 {
            stats.hitCount += 1
            return item
        } else {
            stats.missCount += 1
            // 缓存失效，移除
            cache.removeValue(forKey: path)
            return nil
        }
    }
    
    /// 更新缓存
    func updateCache(for app: AppModel, size: Int64, modificationDate: Date) {
        lock.lock()
        defer { lock.unlock() }
        
        let item = AppCacheItem(
            bundlePath: app.bundleURL.path,
            lastModified: modificationDate.timeIntervalSince1970,
            name: app.bundleName,
            identifier: app.bundleIdentifier,
            version: app.version,
            iconFileName: app.iconFileName,
            size: size
        )
        cache[app.bundleURL.path] = item
    }
    
    /// 清理无效缓存
    /// - Parameter validPaths: 当前有效的应用路径列表
    func cleanInvalidCache(keeping validPaths: Set<String>) {
        lock.lock()
        defer { lock.unlock() }
        
        let initialCount = cache.count
        cache = cache.filter { validPaths.contains($0.key) }
        let removedCount = initialCount - cache.count
        
        if removedCount > 0 {
            logger.info("清理了 \(removedCount) 条无效缓存")
        }
    }
    
    /// 清空所有缓存
    func clearAll() {
        lock.lock()
        defer { lock.unlock() }
        
        cache.removeAll()
        stats = CacheStats()
        
        if let url = cacheFileURL {
            try? fileManager.removeItem(at: url)
        }
    }
    
    /// 获取当前统计信息
    func getStats() -> CacheStats {
        lock.lock()
        defer { lock.unlock() }
        return stats
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .withNavigation(AppManagerPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
