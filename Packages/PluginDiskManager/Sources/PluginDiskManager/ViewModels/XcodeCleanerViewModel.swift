import Foundation
import LumiLoggingKit
import Combine

@MainActor
class XcodeCleanerViewModel: ObservableObject, SuperLog {
    nonisolated static let emoji = "🧹"
    nonisolated static let verbose: Bool = false
    @Published var itemsByCategory: [XcodeCleanCategory: [XcodeCleanItem]] = [:] {
        didSet { rebuildSummary() }
    }
    @Published var isScanning = false
    @Published var isCleaning = false
    @Published var errorMessage: String?
    @Published var isPermissionError = false
    @Published var scanProgress: String = ""
    @Published var scanStats: XcodeCleanService.ScanStats = XcodeCleanService.ScanStats()

    /// 扫描控制栏可见性（#849）：扫描中保留 Stop 入口。
    var isScanControlBarVisible: Bool {
        ScanControlBarVisibility.isVisible(isScanning: isScanning, hasResults: !itemsByCategory.isEmpty)
    }

    // Statistics（#1223 同类问题 #1222）：聚合快照随 itemsByCategory 每次变更
    // 由 didSet 单遍重算一次，footer/分类头读取存储值而非每次 body 求值重复
    // flatMap/filter/reduce 整个结果集。
    private(set) var totalSize: Int64 = 0
    private(set) var selectedSize: Int64 = 0
    private(set) var selectedCount: Int = 0
    private(set) var categorySummary: [XcodeCleanCategory: XcodeCategorySummary] = [:]
    /// 快照重算次数，供回归测试断言「每次更新只重算一次、读取不再重算」。
    private(set) var summaryRebuildCount: Int = 0

    /// 单遍嵌套累加（不产生 flatMap/filter 临时数组），同时算出全局与每分类聚合。
    private func rebuildSummary() {
        var total: Int64 = 0
        var selected: Int64 = 0
        var selectedCount = 0
        var perCategory: [XcodeCleanCategory: XcodeCategorySummary] = [:]
        for (category, items) in itemsByCategory {
            var categorySize: Int64 = 0
            var categorySelectedSize: Int64 = 0
            var categorySelectedCount = 0
            for item in items {
                categorySize += item.size
                if item.isSelected {
                    categorySelectedSize += item.size
                    categorySelectedCount += 1
                }
            }
            perCategory[category] = XcodeCategorySummary(
                size: categorySize,
                selectedSize: categorySelectedSize,
                selectedCount: categorySelectedCount,
                totalCount: items.count
            )
            total += categorySize
            selected += categorySelectedSize
            selectedCount += categorySelectedCount
        }
        totalSize = total
        selectedSize = selected
        self.selectedCount = selectedCount
        categorySummary = perCategory
        summaryRebuildCount += 1
    }

    private let service = XcodeCleanService.shared
    private nonisolated let scanTasks = DiskManagerScanTaskHolder()
    private var hasCompletedInitialScan = false

    init() {
        // Service 不再发布状态，所有状态由 ViewModel 管理
    }

    deinit {
        scanTasks.cancel()
        Task { await XcodeCleanService.shared.cancelScan() }
    }

    func scanAll() async {
        guard !isScanning else { return }
        if Self.verbose {
            if DiskManagerPlugin.verbose {
                            DiskManagerPlugin.logger.info("\(self.t)开始扫描 Xcode 缓存")
            }
        }

        isScanning = true
        itemsByCategory = [:]
        errorMessage = nil
        scanProgress = ""
        scanStats = XcodeCleanService.ScanStats()

        scanTasks.cancelProgress()
        scanTasks.progressTask = Task {
            let stream = await service.progressStream()
            for await stats in stream {
                if Task.isCancelled { break }
                await MainActor.run {
                    self.scanStats = stats
                    self.scanProgress = stats.currentCategory
                }
            }
        }

        scanTasks.scanTask?.cancel()
        scanTasks.scanTask = Task {
            let (stats, results) = await service.scanAllCategories()

            // Apply auto selection for each category
            var processedResults: [XcodeCleanCategory: [XcodeCleanItem]] = [:]
            for (category, items) in results {
                var processedItems = items
                applyAutoSelection(for: category, items: &processedItems)
                processedResults[category] = processedItems

                if Self.verbose {
                    let size = processedItems.reduce(0 as Int64) { $0 + $1.size }
                    let sizeString = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
                    if DiskManagerPlugin.verbose {
                                            DiskManagerPlugin.logger.info("\(self.t)已扫描 \(category.rawValue)：\(processedItems.count) 项，\(sizeString)")
                    }
                }
            }

            if !Task.isCancelled {
                await MainActor.run {
                    self.itemsByCategory = processedResults
                    self.scanStats = stats
                    self.isScanning = false
                    self.hasCompletedInitialScan = true
                    self.scanProgress = ""
                    self.scanTasks.cancelProgress()
                }
            }

            if Self.verbose {
                if DiskManagerPlugin.verbose {
                                    DiskManagerPlugin.logger.info("\(self.t)扫描完成，总计 \(ByteCountFormatter.string(fromByteCount: self.totalSize, countStyle: .file))")
                }
            }
        }
    }

    func scanAllIfNeeded() async {
        guard !hasCompletedInitialScan else { return }
        await scanAll()
    }

    func stopScan() {
        if Self.verbose {
            if DiskManagerPlugin.verbose {
                            DiskManagerPlugin.logger.info("\(self.t)停止扫描 Xcode 缓存")
            }
        }
        cancelScanResources()
        isScanning = false
        scanProgress = ""
    }

    private func cancelScanResources() {
        scanTasks.cancel()
        let service = service
        Task { await service.cancelScan() }
    }

    func toggleSelection(for item: XcodeCleanItem) {
        guard var items = itemsByCategory[item.category] else { return }

        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].isSelected.toggle()
            itemsByCategory[item.category] = items
        }
    }

    func selectAll(in category: XcodeCleanCategory) {
        guard var items = itemsByCategory[category] else { return }
        for index in 0..<items.count {
            items[index].isSelected = true
        }
        itemsByCategory[category] = items
    }

    func deselectAll(in category: XcodeCleanCategory) {
        guard var items = itemsByCategory[category] else { return }
        for index in 0..<items.count {
            items[index].isSelected = false
        }
        itemsByCategory[category] = items
    }

    func cleanSelected() async {
        isCleaning = true
        errorMessage = nil
        isPermissionError = false
        let itemsToDelete = itemsByCategory.values.flatMap { $0 }.filter { $0.isSelected }

        if Self.verbose {
            let size = itemsToDelete.reduce(0 as Int64) { $0 + $1.size }
            let sizeString = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            if DiskManagerPlugin.verbose {
                            DiskManagerPlugin.logger.info("\(self.t)开始清理 \(itemsToDelete.count) 项，共 \(sizeString)")
            }
        }

        do {
            try await service.delete(items: itemsToDelete)
            if Self.verbose {
                if DiskManagerPlugin.verbose {
                                    DiskManagerPlugin.logger.info("\(self.t)清理完成")
                }
            }
            await scanAll()
        } catch {
            if DiskManagerPlugin.verbose {
                            DiskManagerPlugin.logger.error("\(self.t)清理失败：\(error.localizedDescription)")
            }
            let nsError = error as NSError
            let isPermission = (nsError.domain == NSCocoaErrorDomain && nsError.code == 513) ||
                (nsError.domain == NSPOSIXErrorDomain && nsError.code == 13) ||
                nsError.localizedDescription.lowercased().contains("permission") ||
                nsError.localizedDescription.contains("许可")
            isPermissionError = isPermission
            if isPermission {
                errorMessage = PluginDiskManagerLocalization.string("Xcode cleanup requires Full Disk Access. Please grant permission in System Settings.")
            } else {
                errorMessage = PluginDiskManagerLocalization.string("Cleanup failed: \(error.localizedDescription)")
            }
        }

        isCleaning = false
    }

    // MARK: - Auto Selection Logic

    private func applyAutoSelection(for category: XcodeCleanCategory, items: inout [XcodeCleanItem]) {
        switch category {
        case .derivedData, .simulatorCaches, .logs:
            // Select all by default
            for index in 0..<items.count {
                items[index].isSelected = true
            }

        case .iOSDeviceSupport, .watchOSDeviceSupport, .tvOSDeviceSupport:
            // Keep the latest version, select others
            // Sort: Version from high to low
            // Simple parsing: Assume the name starts with the version number

            let sortedIndices = items.indices.sorted { (firstIndex, secondIndex) -> Bool in
                let firstVersion = items[firstIndex].name
                let secondVersion = items[secondIndex].name
                return firstVersion.compare(secondVersion, options: .numeric) == .orderedDescending // Descending
            }

            // Select all except the first one (latest)
            for (rank, index) in sortedIndices.enumerated() where rank > 0 {
                items[index].isSelected = true
            }

        case .archives:
            // Deselect all by default
            break
        }
    }

    // MARK: - Formatting

    func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
