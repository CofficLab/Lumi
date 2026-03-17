import Foundation
import OSLog
import MagicKit

@MainActor
class XcodeCleanService: ObservableObject, SuperLog {
    nonisolated static let emoji = "🧼"
    nonisolated static let verbose = true

    static let shared = XcodeCleanService()
    private let fileManager = FileManager.default

    @Published var isScanning = false
    @Published var scanProgress: String = ""
    @Published var scanStats: ScanStats = ScanStats()

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

    func scanAllCategories() async -> [XcodeCleanCategory: [XcodeCleanItem]] {
        await MainActor.run {
            self.isScanning = true
            self.scanProgress = String(localized: "Initializing...")
            self.scanStats = ScanStats()
        }

        var results: [XcodeCleanCategory: [XcodeCleanItem]] = [:]

        for category in XcodeCleanCategory.allCases {
            await MainActor.run {
                self.scanProgress = category.displayName
                self.scanStats.currentCategory = category.displayName
            }

            let items = await scan(category: category)
            results[category] = items

            await MainActor.run {
                self.scanStats.scannedCategories += 1
                self.scanStats.totalItems += items.count
            }
        }

        await MainActor.run {
            self.isScanning = false
            self.scanProgress = ""
        }

        if Self.verbose {
            os_log("\(self.t)扫描完成：总计 \(self.scanStats.totalItems) 项")
        }

        return results
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
