import Foundation
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

    private let coordinator = XcodeScanCoordinator()

    private init() {
        if Self.verbose {
            DiskManagerPlugin.logger.info("\(self.t)Xcode cleaning service initialized")
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
        await coordinator.scanAll { category in
            await self.scan(category: category)
        }
    }

    func progressStream() async -> AsyncStream<ScanStats> {
        await coordinator.progressStream()
    }

    func cancelScan() async {
        await coordinator.cancelCurrentScan()
    }

    func scan(category: XcodeCleanCategory) async -> [XcodeCleanItem] {
        guard let url = getPath(for: category) else { return [] }
        let tag = self.t

        if Self.verbose {
            DiskManagerPlugin.logger.info("\(tag)Scanning \(category.rawValue): \(url.path)")
        }

        // Heavy I/O (directory listing + size enumeration) must not run on MainActor.
        return await Task.detached(priority: .utility) {
            let fileManager = FileManager.default

            // If directory doesn't exist, return empty
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
                if Self.verbose {
                    DiskManagerPlugin.logger.info("\(tag)Directory does not exist: \(url.path)")
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
                    DiskManagerPlugin.logger.info("\(tag)扫描完成：\(category.rawValue)，\(items.count) 项")
                }
                return items
            } catch {
                DiskManagerPlugin.logger.error("\(self.t)扫描失败：\(category.rawValue) - \(error.localizedDescription)")
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
        DiskManagerPlugin.logger.info("\(tag)开始删除 \(items.count) 项")

        let urls = items.map(\.path)

        try await Task.detached(priority: .utility) {
            let fileManager = FileManager.default

            for (idx, url) in urls.enumerated() {
                if Self.verbose {
                    DiskManagerPlugin.logger.info("\(tag)  └─ 删除[\(idx + 1)/\(urls.count)]：\(url.lastPathComponent)")
                }
                try fileManager.removeItem(at: url)
            }
        }.value

        DiskManagerPlugin.logger.info("\(tag)删除完成：\(items.count) 项")
    }
}

// MARK: - Scan Coordinator

actor XcodeScanCoordinator {
    private var activeTask: Task<(XcodeCleanService.ScanStats, [XcodeCleanCategory: [XcodeCleanItem]]), Never>?
    private var scanID: UUID = UUID()
    private var currentStats: XcodeCleanService.ScanStats? {
        didSet {
            if let s = currentStats {
                for (_, cont) in continuations { cont.yield(s) }
            }
        }
    }
    private var continuations: [UUID: AsyncStream<XcodeCleanService.ScanStats>.Continuation] = [:]

    func progressStream() -> AsyncStream<XcodeCleanService.ScanStats> {
        let id = UUID()
        return AsyncStream { continuation in
            Task { await self.addContinuation(id: id, continuation: continuation) }
            continuation.onTermination = { _ in
                Task { await self.removeContinuation(id: id) }
            }
        }
    }

    private func addContinuation(id: UUID, continuation: AsyncStream<XcodeCleanService.ScanStats>.Continuation) {
        continuations[id] = continuation
        if let s = currentStats { continuation.yield(s) }
    }

    private func removeContinuation(id: UUID) {
        continuations[id] = nil
    }

    func scanAll(scanCategory: @escaping @Sendable (XcodeCleanCategory) async -> [XcodeCleanItem]) async -> (XcodeCleanService.ScanStats, [XcodeCleanCategory: [XcodeCleanItem]]) {
        activeTask?.cancel()
        let myID = UUID()
        scanID = myID
        currentStats = XcodeCleanService.ScanStats(scannedCategories: 0, totalItems: 0, currentCategory: String(localized: "Starting scan..."))

        let task = Task { await performScan(scanCategory: scanCategory, id: myID) }
        activeTask = task
        let result = await task.value

        currentStats = nil
        finishAll()
        return result
    }

    func cancelCurrentScan() {
        activeTask?.cancel()
        activeTask = nil
        currentStats = nil
        scanID = UUID()
        finishAll()
    }

    private func performScan(scanCategory: @Sendable (XcodeCleanCategory) async -> [XcodeCleanItem], id: UUID) async -> (XcodeCleanService.ScanStats, [XcodeCleanCategory: [XcodeCleanItem]]) {
        var results: [XcodeCleanCategory: [XcodeCleanItem]] = [:]
        var stats = XcodeCleanService.ScanStats()

        for category in XcodeCleanCategory.allCases {
            if Task.isCancelled { break }
            stats.currentCategory = category.displayName
            if scanID == id { currentStats = stats } else { break }

            let items = await scanCategory(category)
            results[category] = items

            stats.scannedCategories += 1
            stats.totalItems += items.count
            if scanID == id { currentStats = stats } else { break }
        }

        return (stats, results)
    }

    private func finishAll() {
        for (_, cont) in continuations { cont.finish() }
        continuations.removeAll()
    }
}
