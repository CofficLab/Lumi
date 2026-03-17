import Foundation
import OSLog
import MagicKit

/// Xcode 清理服务 - 在后台执行扫描和清理操作
class XcodeCleanService: @unchecked Sendable, SuperLog {
    nonisolated static let emoji = "🧼"
    nonisolated static let verbose = true

    static let shared = XcodeCleanService()
    private let fileManager = FileManager.default

    // For testing purposes
    var customRootDirectory: URL?

    struct ScanStats {
        var scannedCategories = 0
        var totalItems = 0
        var currentCategory: String = ""
    }

    private init() {
        if Self.verbose {
            os_log("\(self.t)Xcode cleaning service initialized")
        }
    }

    // MARK: - Paths

    private func getPath(for category: XcodeCleanCategory) -> URL? {
        let home = fileManager.homeDirectoryForCurrentUser
        let developer: URL

        if let customRoot = customRootDirectory {
            developer = customRoot.appendingPathComponent("Library/Developer")
        } else {
            developer = home.appendingPathComponent("Library/Developer")
        }

        switch category {
        case .derivedData:
            return developer.appendingPathComponent("Xcode/DerivedData")
        case .archives:
            return developer.appendingPathComponent("Xcode/Archives")
        case .iOSDeviceSupport:
            return developer.appendingPathComponent("Xcode/iOS DeviceSupport")
        case .watchOSDeviceSupport:
            return developer.appendingPathComponent("Xcode/watchOS DeviceSupport")
        case .tvOSDeviceSupport:
            return developer.appendingPathComponent("Xcode/tvOS DeviceSupport")
        case .simulatorCaches:
            return developer.appendingPathComponent("CoreSimulator/Caches")
        case .logs:
            if let customRoot = customRootDirectory {
                return customRoot.appendingPathComponent("Library/Logs/CoreSimulator")
            }
            return home.appendingPathComponent("Library/Logs/CoreSimulator")
        }
    }

    // MARK: - Scanning

    /// 扫描所有类别 - 返回结果，状态由 ViewModel 管理
    func scanAllCategories() async -> (scanStats: ScanStats, itemsByCategory: [XcodeCleanCategory: [XcodeCleanItem]]) {
        if Self.verbose {
            os_log("\(self.t)开始扫描 Xcode 缓存")
        }

        var results: [XcodeCleanCategory: [XcodeCleanItem]] = [:]
        var stats = ScanStats()

        for category in XcodeCleanCategory.allCases {
            stats.currentCategory = category.displayName

            let items = await scan(category: category)
            results[category] = items

            stats.scannedCategories += 1
            stats.totalItems += items.count

            if Self.verbose {
                let size = items.reduce(0 as Int64) { $0 + $1.size }
                os_log("\(self.t)已扫描 \(category.rawValue)：\(items.count) 项，\(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))")
            }
        }

        if Self.verbose {
            os_log("\(self.t)扫描完成，总计 \(stats.totalItems) 项")
        }

        return (stats, results)
    }

    func scan(category: XcodeCleanCategory) async -> [XcodeCleanItem] {
        guard let url = getPath(for: category) else { return [] }
        let tag = self.t

        if Self.verbose {
            os_log("\(tag)Scanning \(category.rawValue): \(url.path)")
        }

        // Heavy I/O (directory listing + size enumeration) must not run on MainActor.
        return await Task.detached(priority: .utility) {
            let fileManager = FileManager.default

            // If directory doesn't exist, return empty
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
                if Self.verbose {
                    os_log("\(tag)Directory does not exist: \(url.path)")
                }
                return []
            }

            do {
                let contents = try fileManager.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: [.contentModificationDateKey],
                    options: [.skipsHiddenFiles]
                )

                var items: [XcodeCleanItem] = []
                items.reserveCapacity(contents.count)

                for itemURL in contents {
                    let size = Self.calculateSize(of: itemURL)
                    let attributes = try itemURL.resourceValues(forKeys: [.contentModificationDateKey])
                    let date = attributes.contentModificationDate ?? Date()

                    var version: String? = nil
                    if category == .iOSDeviceSupport || category == .watchOSDeviceSupport || category == .tvOSDeviceSupport {
                        version = itemURL.lastPathComponent
                    }

                    let item = XcodeCleanItem(
                        name: itemURL.lastPathComponent,
                        path: itemURL,
                        size: size,
                        category: category,
                        modificationDate: date,
                        version: version
                    )
                    items.append(item)
                }

                if Self.verbose {
                    os_log("\(tag)扫描完成：\(category.rawValue)，\(items.count) 项")
                }
                return items
            } catch {
                os_log(.error, "\(self.t)扫描失败：\(category.rawValue) - \(error.localizedDescription)")
                return []
            }
        }.value
    }

    // MARK: - Helpers

    nonisolated private static func calculateSize(of url: URL, fileManager: FileManager) -> Int64 {
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .totalFileAllocatedSizeKey]) else {
            return 0
        }

        var totalSize: Int64 = 0

        for case let fileURL as URL in enumerator {
            do {
                let values = try fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileSizeKey])
                if let size = values.totalFileAllocatedSize ?? values.fileSize {
                    totalSize += Int64(size)
                }
            } catch {
                continue
            }
        }

        return totalSize
    }

    nonisolated private static func calculateSize(of url: URL) -> Int64 {
        let fileManager = FileManager.default
        return calculateSize(of: url, fileManager: fileManager)
    }

    // MARK: - Cleaning

    func delete(items: [XcodeCleanItem]) async throws {
        let tag = self.t
        os_log("\(tag)开始删除 \(items.count) 项")

        let urls = items.map(\.path)

        try await Task.detached(priority: .utility) {
            let fileManager = FileManager.default

            for (idx, url) in urls.enumerated() {
                if Self.verbose {
                    os_log("\(tag)  └─ 删除[\(idx + 1)/\(urls.count)]：\(url.lastPathComponent)")
                }
                try fileManager.removeItem(at: url)
            }
        }.value

        os_log("\(tag)删除完成：\(items.count) 项")
    }
}
