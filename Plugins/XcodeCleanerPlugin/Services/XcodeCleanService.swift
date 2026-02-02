import Foundation
import OSLog
import MagicKit

class XcodeCleanService: SuperLog {
    static let emoji = "🧼"
    static let verbose = false

    static let shared = XcodeCleanService()
    private let fileManager = FileManager.default

    // For testing purposes
    var customRootDirectory: URL?

    private init() {
        if Self.verbose {
            os_log("\(self.t)Xcode 清理服务已初始化")
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
    
    func scan(category: XcodeCleanCategory) async -> [XcodeCleanItem] {
        guard let url = getPath(for: category) else { return [] }

        if Self.verbose {
            os_log("\(self.t)扫描 \(category.rawValue): \(url.path)")
        }

        // 如果目录不存在，直接返回空
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
            if Self.verbose {
                os_log("\(self.t)目录不存在: \(url.path)")
            }
            return []
        }

        do {
            let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles])

            var items: [XcodeCleanItem] = []

            for itemURL in contents {
                // 对于 Archives，Xcode 会按日期 (YYYY-MM-DD) 创建子文件夹，我们需要递归进去看，或者就以日期文件夹为单位？
                // 通常 Archives 结构是 Archives/YYYY-MM-DD/AppName.xcarchive
                // 为了简单起见，我们列出 Archives 下的日期文件夹，或者如果用户希望更细粒度，我们需要扫描所有 .xcarchive。
                // DevCleaner 通常按日期展示。这里我们先按一级子目录（即日期或项目名）展示。

                let size = calculateSize(of: itemURL)
                let attributes = try itemURL.resourceValues(forKeys: [.contentModificationDateKey])
                let date = attributes.contentModificationDate ?? Date()

                var version: String? = nil
                if category == .iOSDeviceSupport || category == .watchOSDeviceSupport || category == .tvOSDeviceSupport {
                    // 尝试从文件夹名称解析版本，例如 "15.2 (19C56)"
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

            return items
        } catch {
            os_log(.error, "\(self.t)扫描失败: \(category.rawValue) - \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Helpers
    
    private func calculateSize(of url: URL) -> Int64 {
        // 简单递归计算大小
        // 注意：这可能很慢，生产环境可能需要优化或使用 URL resource keys
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
    
    // MARK: - Cleaning

    func delete(items: [XcodeCleanItem]) async throws {
        if Self.verbose {
            os_log("\(self.t)开始删除 \(items.count) 个项目")
        }

        for item in items {
            if Self.verbose {
                os_log("\(self.t)删除: \(item.name)")
            }
            try fileManager.removeItem(at: item.path)
        }

        if Self.verbose {
            os_log("\(self.t)删除完成")
        }
    }
}
