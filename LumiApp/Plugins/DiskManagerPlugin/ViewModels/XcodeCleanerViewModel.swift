import Foundation
import Combine
import OSLog
import MagicKit

@MainActor
class XcodeCleanerViewModel: ObservableObject, SuperLog {
    nonisolated static let emoji = "🧹"
    nonisolated static let verbose = true

    @Published var itemsByCategory: [XcodeCleanCategory: [XcodeCleanItem]] = [:]
    @Published var isScanning = false
    @Published var isCleaning = false
    @Published var errorMessage: String?
    @Published var isPermissionError = false
    @Published var scanProgress: String = ""
    @Published var scanStats: XcodeCleanService.ScanStats = XcodeCleanService.ScanStats()

    // Statistics
    var totalSize: Int64 {
        itemsByCategory.values.flatMap { $0 }.reduce(0) { $0 + $1.size }
    }

    var selectedSize: Int64 {
        itemsByCategory.values.flatMap { $0 }.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
    }

    private let service = XcodeCleanService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Subscribe to service scanning state
        service.$isScanning
            .receive(on: RunLoop.main)
            .assign(to: \.isScanning, on: self)
            .store(in: &cancellables)

        service.$scanProgress
            .receive(on: RunLoop.main)
            .assign(to: \.scanProgress, on: self)
            .store(in: &cancellables)

        service.$scanStats
            .receive(on: RunLoop.main)
            .assign(to: \.scanStats, on: self)
            .store(in: &cancellables)
    }

    func scanAll() async {
        if Self.verbose {
            os_log("\(self.t)开始扫描 Xcode 缓存")
        }

        itemsByCategory = [:]
        errorMessage = nil

        let results = await service.scanAllCategories()

        // Apply auto selection for each category
        for (category, items) in results {
            var processedItems = items
            applyAutoSelection(for: category, items: &processedItems)
            itemsByCategory[category] = processedItems

            if Self.verbose {
                let size = processedItems.reduce(0 as Int64) { $0 + $1.size }
                let sizeString = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
                os_log("\(self.t)已扫描 \(category.rawValue)：\(processedItems.count) 项，\(sizeString)")
            }
        }

        if Self.verbose {
            os_log("\(self.t)扫描完成，总计 \(ByteCountFormatter.string(fromByteCount: self.totalSize, countStyle: .file))")
        }
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
            os_log("\(self.t)开始清理 \(itemsToDelete.count) 项，共 \(sizeString)")
        }

        do {
            try await service.delete(items: itemsToDelete)
            if Self.verbose {
                os_log("\(self.t)清理完成")
            }
            await scanAll()
        } catch {
            os_log(.error, "\(self.t)清理失败：\(error.localizedDescription)")
            let nsError = error as NSError
            let isPermission = (nsError.domain == NSCocoaErrorDomain && nsError.code == 513) ||
                (nsError.domain == NSPOSIXErrorDomain && nsError.code == 13) ||
                nsError.localizedDescription.lowercased().contains("permission") ||
                nsError.localizedDescription.contains("许可")
            isPermissionError = isPermission
            if isPermission {
                errorMessage = String(
                    localized: "Xcode cleanup requires Full Disk Access. Please grant permission in System Settings.",
                    table: "DiskManager"
                )
            } else {
                errorMessage = String(localized: "Cleanup failed: \(error.localizedDescription)")
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
