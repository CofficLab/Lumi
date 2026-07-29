import Foundation
import SwiftData
import LumiKernel
import SuperLogKit
import os

/// 活跃数据缓存服务（基于 SwiftData）
///
/// 使用策略：
/// - 今天的数据不缓存，每次实时查询
/// - 昨天及以前的数据缓存到 SwiftData 数据库，历史数据不会变化
/// - 批量查询替代数百次文件 I/O
public actor ActivityHeatmapCache: SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.activity-heatmap.cache")
    public nonisolated static let emoji = "💾"
    public static var verbose = false

    // MARK: - Properties

    private let container: ModelContainer
    private let databaseDirectory: URL

    /// 数据库目录，供设置页面打开
    public nonisolated var databaseDirectoryURL: URL { databaseDirectory }

    // MARK: - Init

    public init(storage: (any StorageProviding)?, pluginID: String) {
        let dbDir: URL
        if let storage = storage {
            dbDir = storage.pluginDataDirectory(for: pluginID)
        } else {
            // Fallback to temp directory (should not happen in production)
            dbDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("Lumi/ActivityHeatmap")
        }
        self.databaseDirectory = dbDir

        // 创建 ModelContainer
        let dbURL = dbDir.appendingPathComponent("cache.sqlite", isDirectory: false)
        let schema = Schema([ActivityCacheEntry.self])
        let config = ModelConfiguration(
            schema: schema,
            url: dbURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        do {
            // 确保目录存在
            try FileManager.default.createDirectory(at: dbDir, withIntermediateDirectories: true)
            self.container = try ModelContainer(for: schema, configurations: [config])
            if Self.verbose {
                Self.logger.info("\(Self.t)SwiftData 数据库已初始化: \(dbURL.path)")
            }
        } catch {
            Self.logger.error("\(Self.t)创建 SwiftData 数据库失败: \(error.localizedDescription)")
            // Fallback to in-memory container
            self.container = try! ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
            )
        }
    }

    // MARK: - Load

    /// 加载指定日期的 heatmap 缓存数据
    public func loadHeatmapCount(for date: Date) async -> Int? {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<ActivityCacheEntry>(
            predicate: #Predicate { $0.date == normalizedDate }
        )

        do {
            let results = try context.fetch(descriptor)
            return results.first?.heatmapCount
        } catch {
            Self.logger.error("\(Self.t)加载 heatmap 缓存失败: \(error.localizedDescription)")
            return nil
        }
    }

    /// 批量加载多个日期的 heatmap 缓存数据（一次查询替代 N 次文件 I/O）
    public func loadHeatmapCounts(for dates: [Date]) async -> [Date: Int] {
        guard !dates.isEmpty else { return [:] }

        let cal = Calendar.current
        let normalizedDates = Set(dates.map { cal.startOfDay(for: $0) })
        let context = ModelContext(container)

        let descriptor = FetchDescriptor<ActivityCacheEntry>(
            predicate: #Predicate { normalizedDates.contains($0.date) }
        )

        do {
            let results = try context.fetch(descriptor)
            var dict: [Date: Int] = [:]
            for entry in results {
                dict[entry.date] = entry.heatmapCount
            }
            return dict
        } catch {
            Self.logger.error("\(Self.t)批量加载 heatmap 缓存失败: \(error.localizedDescription)")
            return [:]
        }
    }

    /// 加载指定日期的 token 缓存数据
    public func loadTokenCount(for date: Date) async -> Int? {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<ActivityCacheEntry>(
            predicate: #Predicate { $0.date == normalizedDate }
        )

        do {
            let results = try context.fetch(descriptor)
            return results.first?.tokenCount
        } catch {
            Self.logger.error("\(Self.t)加载 token 缓存失败: \(error.localizedDescription)")
            return nil
        }
    }

    /// 批量加载多个日期的 token 缓存数据（一次查询替代 N 次文件 I/O）
    public func loadTokenCounts(for dates: [Date]) async -> [Date: Int] {
        guard !dates.isEmpty else { return [:] }

        let cal = Calendar.current
        let normalizedDates = Set(dates.map { cal.startOfDay(for: $0) })
        let context = ModelContext(container)

        let descriptor = FetchDescriptor<ActivityCacheEntry>(
            predicate: #Predicate { normalizedDates.contains($0.date) }
        )

        do {
            let results = try context.fetch(descriptor)
            var dict: [Date: Int] = [:]
            for entry in results {
                dict[entry.date] = entry.tokenCount
            }
            return dict
        } catch {
            Self.logger.error("\(Self.t)批量加载 token 缓存失败: \(error.localizedDescription)")
            return [:]
        }
    }

    // MARK: - Save

    /// 保存单日数据到缓存（upsert 语义）
    public func saveCounts(heatmapCount: Int?, tokenCount: Int?, for date: Date) async {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        let context = ModelContext(container)

        let descriptor = FetchDescriptor<ActivityCacheEntry>(
            predicate: #Predicate { $0.date == normalizedDate }
        )

        do {
            if let existing = try context.fetch(descriptor).first {
                // 更新现有记录
                if let hc = heatmapCount {
                    existing.heatmapCount = hc
                }
                if let tc = tokenCount {
                    existing.tokenCount = tc
                }
            } else {
                // 插入新记录
                let entry = ActivityCacheEntry(
                    date: normalizedDate,
                    heatmapCount: heatmapCount ?? 0,
                    tokenCount: tokenCount ?? 0
                )
                context.insert(entry)
            }

            try context.save()
        } catch {
            Self.logger.error("\(Self.t)保存缓存失败: \(error.localizedDescription)")
        }
    }

    /// 保存 heatmap 数据（兼容旧接口）
    public func saveHeatmapCount(_ count: Int, for date: Date) async {
        await saveCounts(heatmapCount: count, tokenCount: nil, for: date)
    }

    /// 保存 token 数据（兼容旧接口）
    public func saveTokenCount(_ count: Int, for date: Date) async {
        await saveCounts(heatmapCount: nil, tokenCount: count, for: date)
    }

    // MARK: - Cache Management

    /// 获取缓存数据库文件大小
    public func cacheSize() -> Int64 {
        let dbURL = databaseDirectory.appendingPathComponent("cache.sqlite", isDirectory: false)
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: dbURL.path) else {
            return 0
        }

        do {
            let attrs = try fileManager.attributesOfItem(atPath: dbURL.path)
            let mainSize = (attrs[.size] as? Int64) ?? 0

            // 统计 WAL 和 SHM 文件
            var totalSize = mainSize
            for suffix in ["-wal", "-shm"] {
                let walURL = databaseDirectory.appendingPathComponent("cache.sqlite\(suffix)", isDirectory: false)
                if fileManager.fileExists(atPath: walURL.path) {
                    let walAttrs = try fileManager.attributesOfItem(atPath: walURL.path)
                    totalSize += (walAttrs[.size] as? Int64) ?? 0
                }
            }

            return totalSize
        } catch {
            Self.logger.error("\(Self.t)计算缓存大小失败: \(error.localizedDescription)")
            return 0
        }
    }

    /// 清理过期缓存（保留最近 N 天）
    public func cleanExpiredCache(keepDays: Int = 365) async {
        let cal = Calendar.current
        guard let cutoffDate = cal.date(byAdding: .day, value: -keepDays, to: Date()) else {
            return
        }

        let cutoffNormalized = cal.startOfDay(for: cutoffDate)
        let context = ModelContext(container)

        let descriptor = FetchDescriptor<ActivityCacheEntry>(
            predicate: #Predicate { $0.date < cutoffNormalized }
        )

        do {
            let expiredEntries = try context.fetch(descriptor)
            for entry in expiredEntries {
                context.delete(entry)
            }

            if !expiredEntries.isEmpty {
                try context.save()
                if Self.verbose {
                    Self.logger.info("\(Self.t)已清理 \(expiredEntries.count) 条过期缓存")
                }
            }
        } catch {
            Self.logger.error("\(Self.t)清理过期缓存失败: \(error.localizedDescription)")
        }
    }
}
