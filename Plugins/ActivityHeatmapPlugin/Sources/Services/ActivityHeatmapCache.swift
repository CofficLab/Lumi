import Foundation
import LumiKernel
import SuperLogKit
import os

/// 活跃数据磁盘缓存服务
///
/// 使用策略：
/// - 今天的数据不缓存，每次实时查询
/// - 昨天及以前的数据缓存到磁盘，历史数据不会变化
@MainActor
public final class ActivityHeatmapCache: SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.activity-heatmap.cache")
    public nonisolated static let emoji = "💾"
    public static var verbose = false

    // MARK: - Constants

    private static let heatmapDirectoryName = "heatmap"
    private static let tokensDirectoryName = "tokens"

    // MARK: - Properties

    private let cacheDirectory: URL

    /// Exposed for plugin settings view to open the directory in Finder
    package var directory: URL { cacheDirectory }

    // MARK: - Init

    public init(storage: (any StorageProviding)?, pluginID: String) {
        if let storage = storage {
            self.cacheDirectory = storage.pluginDataDirectory(for: pluginID)
        } else {
            // Fallback to temp directory (should not happen in production)
            self.cacheDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent("Lumi/ActivityHeatmap")
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)缓存目录: \(self.cacheDirectory.path)")
        }
    }

    // MARK: - Load

    /// 加载指定日期的缓存数据
    public func loadHeatmapCount(for date: Date) -> Int? {
        let fileURL = Self.heatmapFileURL(for: date, in: cacheDirectory)

        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let wrapper = try? JSONDecoder().decode(HeatmapCacheWrapper.self, from: data)
        else {
            return nil
        }

        return wrapper.count
    }

    /// 批量加载多个日期的缓存数据
    public func loadHeatmapCounts(for dates: [Date]) -> [Date: Int] {
        var results: [Date: Int] = [:]
        let cal = Calendar.current

        for date in dates {
            let normalizedDate = cal.startOfDay(for: date)
            if let count = loadHeatmapCount(for: normalizedDate) {
                results[normalizedDate] = count
            }
        }

        return results
    }

    /// 加载指定日期的 token 缓存数据
    public func loadTokenCount(for date: Date) -> Int? {
        let fileURL = Self.tokensFileURL(for: date, in: cacheDirectory)

        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let wrapper = try? JSONDecoder().decode(TokenCacheWrapper.self, from: data)
        else {
            return nil
        }

        return wrapper.count
    }

    /// 批量加载多个日期的 token 缓存数据
    public func loadTokenCounts(for dates: [Date]) -> [Date: Int] {
        var results: [Date: Int] = [:]
        let cal = Calendar.current

        for date in dates {
            let normalizedDate = cal.startOfDay(for: date)
            if let count = loadTokenCount(for: normalizedDate) {
                results[normalizedDate] = count
            }
        }

        return results
    }

    // MARK: - Save

    /// 保存单日数据到缓存
    public func saveHeatmapCount(_ count: Int, for date: Date) {
        let fileURL = Self.heatmapFileURL(for: date, in: cacheDirectory)
        let wrapper = HeatmapCacheWrapper(date: date, count: count)
        Self.write(wrapper, to: fileURL)
    }

    /// 保存单日 token 数据到缓存
    public func saveTokenCount(_ count: Int, for date: Date) {
        let fileURL = Self.tokensFileURL(for: date, in: cacheDirectory)
        let wrapper = TokenCacheWrapper(date: date, count: count)
        Self.write(wrapper, to: fileURL)
    }

    // MARK: - Cache Management

    /// 获取缓存文件大小
    public func cacheSize() -> Int64 {
        var totalSize: Int64 = 0
        let fileManager = FileManager.default

        for dirName in [Self.heatmapDirectoryName, Self.tokensDirectoryName] {
            let dirURL = cacheDirectory.appendingPathComponent(dirName, isDirectory: true)
            if let enumerator = fileManager.enumerator(at: dirURL, includingPropertiesForKeys: [.fileSizeKey]) {
                for case let fileURL as URL in enumerator {
                    if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                        totalSize += Int64(fileSize)
                    }
                }
            }
        }

        return totalSize
    }

    /// 清理过期缓存（保留最近 N 天）
    public func cleanExpiredCache(keepDays: Int = 365) {
        let cal = Calendar.current
        guard let cutoffDate = cal.date(byAdding: .day, value: -keepDays, to: Date()) else {
            return
        }

        let cutoffNormalized = cal.startOfDay(for: cutoffDate)

        for dirName in [Self.heatmapDirectoryName, Self.tokensDirectoryName] {
            let dirURL = cacheDirectory.appendingPathComponent(dirName, isDirectory: true)
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: dirURL,
                includingPropertiesForKeys: [.creationDateKey]
            ) else {
                continue
            }

            for fileURL in contents {
                if let creationDate = try? fileURL.resourceValues(forKeys: [.creationDateKey]).creationDate,
                   cal.startOfDay(for: creationDate) < cutoffNormalized {
                    try? FileManager.default.removeItem(at: fileURL)
                    if Self.verbose {
                        Self.logger.info("\(Self.t)删除过期缓存: \(fileURL.lastPathComponent)")
                    }
                }
            }
        }
    }

    // MARK: - Private Helpers

    private static func heatmapFileURL(for date: Date, in cacheDirectory: URL) -> URL {
        let dateString = Self.formatDateString(for: date)
        return cacheDirectory
            .appendingPathComponent(heatmapDirectoryName, isDirectory: true)
            .appendingPathComponent("heatmap-\(dateString).json", isDirectory: false)
    }

    private static func tokensFileURL(for date: Date, in cacheDirectory: URL) -> URL {
        let dateString = Self.formatDateString(for: date)
        return cacheDirectory
            .appendingPathComponent(tokensDirectoryName, isDirectory: true)
            .appendingPathComponent("tokens-\(dateString).json", isDirectory: false)
    }

    package static func formatDateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func write<Value: Encodable>(_ value: Value, to fileURL: URL) {
        guard let data = try? JSONEncoder().encode(value) else {
            return
        }

        // Ensure parent directory exists
        let parentDir = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)

        let tempURL = parentDir.appendingPathComponent("\(fileURL.lastPathComponent).tmp", isDirectory: false)

        do {
            try data.write(to: tempURL, options: .atomic)

            if FileManager.default.fileExists(atPath: fileURL.path) {
                _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: tempURL)
            } else {
                try FileManager.default.moveItem(at: tempURL, to: fileURL)
            }
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            if Self.verbose {
                Self.logger.error("\(Self.t)写入缓存失败: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Cache Data Models

/// 单日 heatmap 数据缓存包装器
struct HeatmapCacheWrapper: Codable {
    let date: Date
    let count: Int
}

/// 单日 token 数据缓存包装器
struct TokenCacheWrapper: Codable {
    let date: Date
    let count: Int
}
