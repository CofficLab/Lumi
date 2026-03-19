import Foundation
import MagicKit
import SwiftData
import SwiftUI

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

/// 缓存管理器 - 使用 SwiftData 持久化
actor CacheManager: SuperLog {
    nonisolated static let emoji = "💾"
    nonisolated static let verbose = false

    static let shared = CacheManager()

    private let container: ModelContainer

    private(set) var stats = CacheStats()

    private init() {
        let schema = Schema([AppCacheItem.self])

        let dbDir = AppConfig.getDBFolderURL().appendingPathComponent("AppManagerPlugin", isDirectory: true)
        try? FileManager.default.createDirectory(at: dbDir, withIntermediateDirectories: true)
        let dbURL = dbDir.appendingPathComponent("AppCache.sqlite")

        let config = ModelConfiguration(
            schema: schema,
            url: dbURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        do {
            self.container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create AppManager Cache ModelContainer: \(error)")
        }
    }

    /// 获取缓存的应用信息
    func getCachedApp(at path: String, currentModificationDate: Date) async -> AppCacheItemDTO? {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<AppCacheItem>(
            predicate: #Predicate<AppCacheItem> { $0.bundlePath == path }
        )

        guard let item = try? context.fetch(descriptor).first else {
            stats.missCount += 1
            if Self.verbose {
                AppManagerPlugin.logger.info("\(self.t)缓存未命中：\((path as NSString).lastPathComponent)")
            }
            return nil
        }

        // 验证时间戳（允许 1 秒内的误差）
        if abs(item.lastModified - currentModificationDate.timeIntervalSince1970) < 1.0 {
            stats.hitCount += 1
            if Self.verbose {
                AppManagerPlugin.logger.info("\(self.t)缓存命中：\(item.name)")
            }
            return item.toDTO()
        } else {
            stats.missCount += 1
            if Self.verbose {
                AppManagerPlugin.logger.info("\(self.t)缓存已过期：\(item.name)，已移除")
            }
            context.delete(item)
            try? context.save()
            return nil
        }
    }

    /// 更新缓存
    func updateCache(for app: AppModel, size: Int64, modificationDate: Date) async {
        let context = ModelContext(container)
        let path = app.bundleURL.path

        let descriptor = FetchDescriptor<AppCacheItem>(
            predicate: #Predicate<AppCacheItem> { $0.bundlePath == path }
        )

        if let existing = try? context.fetch(descriptor).first {
            existing.lastModified = modificationDate.timeIntervalSince1970
            existing.name = app.bundleName
            existing.identifier = app.bundleIdentifier
            existing.version = app.version
            existing.iconFileName = app.iconFileName
            existing.size = size
        } else {
            let item = AppCacheItem(
                bundlePath: path,
                lastModified: modificationDate.timeIntervalSince1970,
                name: app.bundleName,
                identifier: app.bundleIdentifier,
                version: app.version,
                iconFileName: app.iconFileName,
                size: size
            )
            context.insert(item)
        }

        try? context.save()

        if Self.verbose {
            AppManagerPlugin.logger.info("\(self.t)缓存已更新：\(app.displayName)")
        }
    }

    /// 清理无效缓存
    func cleanInvalidCache(keeping validPaths: Set<String>) async {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<AppCacheItem>()
        guard let allItems = try? context.fetch(descriptor) else { return }

        var removedCount = 0
        for item in allItems {
            if !validPaths.contains(item.bundlePath) {
                context.delete(item)
                removedCount += 1
            }
        }

        if removedCount > 0 {
            try? context.save()
            if Self.verbose {
                AppManagerPlugin.logger.info("\(self.t)清理无效缓存：\(removedCount) 条")
            }
        }
    }

    /// 保存缓存（数据库模式下跌落为 no-op，每次更新已立即持久化）
    func saveCache() async {
        // SwiftData 在 updateCache/cleanInvalidCache 时已 save，此处无需操作
    }

    /// 清空所有缓存
    func clearAll() {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<AppCacheItem>()
        guard let allItems = try? context.fetch(descriptor) else { return }

        for item in allItems {
            context.delete(item)
        }
        try? context.save()

        let oldStats = stats
        stats = CacheStats()

        if Self.verbose {
            AppManagerPlugin.logger.info("\(self.t)缓存已清空。之前统计：\(oldStats.hitCount) 命中，\(oldStats.missCount) 未命中")
        }
    }

    /// 获取当前统计信息
    func getStats() async -> CacheStats {
        stats
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .withNavigation(AppManagerPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
