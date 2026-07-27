import Foundation
import os
import LumiKernel

/// Xcode clean service - scans and cleans Xcode-related caches.
public final class XcodeCleanService: @unchecked Sendable {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "xcode-clean")
    public static let shared = XcodeCleanService()
    private let fileManager = FileManager.default

    public var customRootDirectory: URL?

    public struct ScanStats: Sendable {
        public var scannedCategories = 0
        public var totalItems = 0
        public var currentCategory: String = ""

        public init(scannedCategories: Int = 0, totalItems: Int = 0, currentCategory: String = "") {
            self.scannedCategories = scannedCategories
            self.totalItems = totalItems
            self.currentCategory = currentCategory
        }
    }

    private let coordinator = XcodeScanCoordinator()

    private init() {}

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

    public func scanAllCategories() async -> (scanStats: ScanStats, itemsByCategory: [XcodeCleanCategory: [XcodeCleanItem]]) {
        await coordinator.scanAll { category in
            await self.scan(category: category)
        }
    }

    public func progressStream() async -> AsyncStream<ScanStats> {
        await coordinator.progressStream()
    }

    public func cancelScan() async {
        await coordinator.cancelCurrentScan()
    }

    public func scan(category: XcodeCleanCategory) async -> [XcodeCleanItem] {
        guard let url = getPath(for: category) else { return [] }

        return await Task.detached(priority: .utility) {
            let fileManager = FileManager.default

            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
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
                return items
            } catch {
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

    public func delete(items: [XcodeCleanItem]) async throws {
        let urls = items.map(\.path)

        try await Task.detached(priority: .utility) {
            let fileManager = FileManager.default
            for url in urls {
                try fileManager.removeItem(at: url)
            }
        }.value
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
        currentStats = XcodeCleanService.ScanStats(scannedCategories: 0, totalItems: 0, currentCategory: LumiPluginLocalization.string("Starting scan...", bundle: .module))

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
