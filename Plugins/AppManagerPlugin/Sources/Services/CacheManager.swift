import Foundation
import SuperLogKit
import SwiftData

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
    nonisolated static let verbose: Bool = true
    static let shared = CacheManager()

    private let container: ModelContainer

    private(set) var stats = CacheStats()

    private init() {
        self.container = Self.makeContainer(databaseRootURL: AppManagerPlugin.databaseRootURLProvider())
    }

    init(databaseRootURL: URL) {
        self.container = Self.makeContainer(databaseRootURL: databaseRootURL)
    }

    static func makeContainer(databaseRootURL: URL) -> ModelContainer {
        let schema = Schema([AppCacheItem.self])
        let dbDir = databaseRootURL.appendingPathComponent("AppManagerPlugin", isDirectory: true)
        let dbURL = dbDir.appendingPathComponent("AppCache.sqlite")
        let fileManager = FileManager.default

        do {
            quarantineFileIfItBlocksDirectory(at: dbDir)
            try fileManager.createDirectory(at: dbDir, withIntermediateDirectories: true)
        } catch {
            if AppManagerPlugin.verbose {
                AppManagerPlugin.logger.error("\(Self.t)创建应用缓存数据库目录失败：\(error.localizedDescription)")
            }
        }

        let config = ModelConfiguration(
            schema: schema,
            url: dbURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            if AppManagerPlugin.verbose {
                AppManagerPlugin.logger.error("\(Self.t)打开应用缓存数据库失败，准备重建：\(error.localizedDescription)")
            }
            quarantinePersistentStore(at: dbURL)
        }

        do {
            try fileManager.createDirectory(at: dbDir, withIntermediateDirectories: true)
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            if AppManagerPlugin.verbose {
                AppManagerPlugin.logger.error("\(Self.t)重建应用缓存数据库失败，使用临时内存缓存：\(error.localizedDescription)")
            }
            return makeInMemoryContainer(schema: schema)
        }
    }

    private static func makeInMemoryContainer(schema: Schema) -> ModelContainer {
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            preconditionFailure("Could not create in-memory AppManager Cache ModelContainer: \(error)")
        }
    }

    private static func quarantinePersistentStore(at dbURL: URL) {
        let fileManager = FileManager.default
        let storeURLs = [
            dbURL,
            URL(fileURLWithPath: dbURL.path + "-shm"),
            URL(fileURLWithPath: dbURL.path + "-wal")
        ]

        for url in storeURLs where fileManager.fileExists(atPath: url.path) {
            quarantineFile(at: url)
        }
    }

    private static func quarantineFileIfItBlocksDirectory(at url: URL) {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              !isDirectory.boolValue else {
            return
        }

        quarantineFile(at: url)
    }

    private static func quarantineFile(at url: URL) {
        let destination = url.deletingLastPathComponent()
            .appendingPathComponent(url.lastPathComponent + ".corrupt-\(Int(Date().timeIntervalSince1970))")
        do {
            try FileManager.default.moveItem(at: url, to: destination)
        } catch {
            if AppManagerPlugin.verbose {
                AppManagerPlugin.logger.error("\(Self.t)隔离应用缓存数据库文件失败：\(error.localizedDescription)")
            }
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
                if AppManagerPlugin.verbose {
                                    AppManagerPlugin.logger.info("\(self.t)缓存未命中：\((path as NSString).lastPathComponent)")
                }
            }
            return nil
        }

        // 验证时间戳（允许 1 秒内的误差）
        if abs(item.lastModified - currentModificationDate.timeIntervalSince1970) < 1.0 {
            stats.hitCount += 1
            if Self.verbose {
                if AppManagerPlugin.verbose {
                                    AppManagerPlugin.logger.info("\(self.t)缓存命中：\(item.name)")
                }
            }
            return item.toDTO()
        } else {
            stats.missCount += 1
            if Self.verbose {
                if AppManagerPlugin.verbose {
                                    AppManagerPlugin.logger.info("\(self.t)缓存已过期：\(item.name)，已移除")
                }
            }
            context.delete(item)
            _ = save(context, operation: "移除过期应用缓存")
            return nil
        }
    }

    /// 更新缓存
    @discardableResult
    func updateCache(for app: AppModel, size: Int64, modificationDate: Date) async -> Bool {
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

        let saved = save(context, operation: "保存应用缓存")

        if saved, Self.verbose {
            if AppManagerPlugin.verbose {
                            AppManagerPlugin.logger.info("\(self.t)缓存已更新：\(app.displayName)")
            }
        }
        return saved
    }

    /// 清理无效缓存
    @discardableResult
    func cleanInvalidCache(keeping validPaths: Set<String>) async -> Bool {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<AppCacheItem>()
        guard let allItems = try? context.fetch(descriptor) else { return false }

        var removedCount = 0
        for item in allItems {
            if !validPaths.contains(item.bundlePath) {
                context.delete(item)
                removedCount += 1
            }
        }

        if removedCount > 0 {
            let saved = save(context, operation: "清理无效应用缓存")
            if saved, Self.verbose {
                if AppManagerPlugin.verbose {
                                    AppManagerPlugin.logger.info("\(self.t)清理无效缓存：\(removedCount) 条")
                }
            }
            return saved
        }
        return true
    }

    /// 保存缓存（数据库模式下跌落为 no-op，每次更新已立即持久化）
    func saveCache() async {
        // SwiftData 在 updateCache/cleanInvalidCache 时已 save，此处无需操作
    }

    /// 清空所有缓存
    @discardableResult
    func clearAll() -> Bool {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<AppCacheItem>()
        guard let allItems = try? context.fetch(descriptor) else { return false }

        for item in allItems {
            context.delete(item)
        }
        let saved = save(context, operation: "清空应用缓存")
        guard saved else { return false }

        let oldStats = stats
        stats = CacheStats()

        if Self.verbose {
            if AppManagerPlugin.verbose {
                            AppManagerPlugin.logger.info("\(self.t)缓存已清空。之前统计：\(oldStats.hitCount) 命中，\(oldStats.missCount) 未命中")
            }
        }
        return true
    }

    /// 获取当前统计信息
    func getStats() async -> CacheStats {
        stats
    }

    private func save(_ context: ModelContext, operation: StaticString) -> Bool {
        do {
            try context.save()
            return true
        } catch {
            if AppManagerPlugin.verbose {
                AppManagerPlugin.logger.error("\(self.t)\(operation)失败：\(error.localizedDescription)")
            }
            return false
        }
    }
}
