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
    private static let tokenCacheVersion = "2"

    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.activity-heatmap.cache")
    public nonisolated static let emoji = "💾"
    public nonisolated static let verbose = true

    // MARK: - Properties

    private let container: ModelContainer
    private let databaseDirectory: URL
    private let tokenCacheVersionURL: URL
    private var tokenCacheNeedsRefresh: Bool

    /// 数据库目录，供设置页面打开
    public nonisolated var databaseDirectoryURL: URL { databaseDirectory }

    // MARK: - Init

    public init(storageDirectory: URL?, pluginID: String) {
        // Fallback to temp directory (should not happen in production)
        let dbDir = storageDirectory ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("Lumi/ActivityHeatmap")
        self.databaseDirectory = dbDir
        let tokenCacheVersionURL = dbDir.appendingPathComponent("token-cache-version", isDirectory: false)
        self.tokenCacheVersionURL = tokenCacheVersionURL
        let storedVersion = try? String(contentsOf: tokenCacheVersionURL, encoding: .utf8)
        self.tokenCacheNeedsRefresh = storedVersion?.trimmingCharacters(in: .whitespacesAndNewlines) != Self.tokenCacheVersion

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
        guard !tokenCacheNeedsRefresh else { return [:] }

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

    /// 批量保存多个日期的缓存数据。
    ///
    /// 每个传入日期都会写入一条记录，即使值为 0 也会写入，避免无活动
    /// 的日期在下一次加载时再次被判断为 cache miss。所有 upsert 在一个
    /// ModelContext 和一次 save 中完成，避免逐日事务带来的启动延迟。
    public func saveCounts(
        heatmapCounts: [Date: Int],
        tokenCounts: [Date: Int]
    ) async {
        let dates = Set(heatmapCounts.keys).union(tokenCounts.keys)
        guard !dates.isEmpty else { return }

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<ActivityCacheEntry>(
            predicate: #Predicate { dates.contains($0.date) }
        )

        do {
            let existingEntries = try context.fetch(descriptor)
            var entriesByDate = Dictionary(
                uniqueKeysWithValues: existingEntries.map { ($0.date, $0) }
            )

            for date in dates {
                if let existing = entriesByDate[date] {
                    existing.heatmapCount = heatmapCounts[date] ?? existing.heatmapCount
                    existing.tokenCount = tokenCounts[date] ?? existing.tokenCount
                } else {
                    let entry = ActivityCacheEntry(
                        date: date,
                        heatmapCount: heatmapCounts[date] ?? 0,
                        tokenCount: tokenCounts[date] ?? 0
                    )
                    context.insert(entry)
                    entriesByDate[date] = entry
                }
            }

            try context.save()
            if !tokenCounts.isEmpty {
                try Self.tokenCacheVersion.write(to: tokenCacheVersionURL, atomically: true, encoding: .utf8)
                tokenCacheNeedsRefresh = false
            }
        } catch {
            Self.logger.error("\(Self.t)批量保存 heatmap 缓存失败: \(error.localizedDescription)")
        }
    }

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
            if tokenCount != nil {
                try Self.tokenCacheVersion.write(to: tokenCacheVersionURL, atomically: true, encoding: .utf8)
                tokenCacheNeedsRefresh = false
            }
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
