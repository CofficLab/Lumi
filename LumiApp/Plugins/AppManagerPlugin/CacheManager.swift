import Foundation
import SwiftUI
import MagicKit
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
actor CacheManager: SuperLog {
    nonisolated static let emoji = "💾"
    nonisolated static let verbose = false

    static let shared = CacheManager()

    private let cacheFileName = "app_cache.json"
    private var cache: [String: AppCacheItem] = [:]
    private let fileManager = FileManager.default

    private(set) var stats = CacheStats()

    private var cacheDirectory: URL? {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("com.coffic.lumi/AppManagerPlugin")
    }

    private var cacheFileURL: URL? {
        cacheDirectory?.appendingPathComponent(cacheFileName)
    }

    private init() {
        // Actor init 不能访问实例方法，延迟到首次使用时初始化
    }

    /// 确保缓存已初始化（首次访问时调用）
    private func ensureInitialized() async {
        if cache.isEmpty {
            await createCacheDirectoryIfNeeded()
            await loadCache()
        }
    }

    private func createCacheDirectoryIfNeeded() async {
        guard let cacheDirectory = cacheDirectory else { return }
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            do {
                try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
                if Self.verbose {
                    os_log("\(self.t)Created cache directory: \(cacheDirectory.path)")
                }
            } catch {
                os_log(.error, "\(self.t)Failed to create cache directory: \(error.localizedDescription)")
            }
        }
    }

    /// 加载缓存
    private func loadCache() async {
        guard let url = cacheFileURL,
              fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else {
            if Self.verbose {
                os_log("\(self.t)No cache file found")
            }
            return
        }

        do {
            let decoder = JSONDecoder()
            cache = try decoder.decode([String: AppCacheItem].self, from: data)
            if Self.verbose {
                os_log("\(self.t)Cache loaded successfully: \(self.cache.count) entries")
            }
        } catch {
            os_log(.error, "\(self.t)Failed to load cache: \(error.localizedDescription)")
            // 缓存损坏，重置
            cache = [:]
        }
    }

    /// 保存缓存
    func saveCache() async {
        guard let url = cacheFileURL else { return }

        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(cache)
            try data.write(to: url, options: .atomic)
            if Self.verbose {
                os_log("\(self.t)Cache saved successfullself.y: \(self.cache.count) entries")
            }
        } catch {
            os_log(.error, "\(self.t)Failed to save cache: \(error.localizedDescription)")
        }
    }

    /// 获取缓存的应用信息
    /// - Parameters:
    ///   - path: 应用路径
    ///   - currentModificationDate: 当前文件修改时间
    /// - Returns: 缓存项（如果有效）
    func getCachedApp(at path: String, currentModificationDate: Date) async -> AppCacheItem? {
        await ensureInitialized()
        guard let item = cache[path] else {
            stats.missCount += 1
            if Self.verbose {
                os_log("\(self.t)Cache miss for: \(path.components(separatedBy: "/").last ?? path)")
            }
            return nil
        }

        // 验证时间戳（允许 1 秒内的误差）
        if abs(item.lastModified - currentModificationDate.timeIntervalSince1970) < 1.0 {
            stats.hitCount += 1
            if Self.verbose {
                os_log("\(self.t)Cache hit for: \(item.name)")
            }
            return item
        } else {
            stats.missCount += 1
            if Self.verbose {
                os_log("\(self.t)Cache stale for: \(item.name), removing")
            }
            // 缓存失效，移除
            cache.removeValue(forKey: path)
            return nil
        }
    }

    /// 更新缓存
    func updateCache(for app: AppModel, size: Int64, modificationDate: Date) async {
        await ensureInitialized()
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

        if Self.verbose {
            os_log("\(self.t)Cache updated for: \(app.displayName)")
        }
    }

    /// 清理无效缓存
    /// - Parameter validPaths: 当前有效的应用路径列表
    func cleanInvalidCache(keeping validPaths: Set<String>) async {
        let initialCount = cache.count
        cache = cache.filter { validPaths.contains($0.key) }
        let removedCount = initialCount - cache.count

        if removedCount > 0 {
            if Self.verbose {
                os_log("\(self.t)Cleaned \(removedCount) invalid cache entries")
            }
        }
    }

    /// 清空所有缓存
    func clearAll() {
        cache.removeAll()
        let oldStats = stats
        stats = CacheStats()

        if let url = cacheFileURL {
            try? fileManager.removeItem(at: url)
        }

        if Self.verbose {
            os_log("\(self.t)Cache cleared. Previous stats: \(oldStats.hitCount) hits, \(oldStats.missCount) misses")
        }
    }

    /// 获取当前统计信息
    func getStats() async -> CacheStats {
        return stats
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .withNavigation(AppManagerPlugin.navigationId)
        .inRootView("Preview")
        .withDebugBar()
}
