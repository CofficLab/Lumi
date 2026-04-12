import Foundation
import Combine
import MagicKit

@MainActor
class CacheCleanerViewModel: ObservableObject, SuperLog {
    nonisolated static let emoji = "🗑️"
    nonisolated static let verbose: Bool = true    @Published var categories: [CacheCategory] = []
    @Published var isScanning = false
    @Published var isCleaning = false
    @Published var scanProgress: String = ""
    @Published var selection: Set<UUID> = [] // Selected CachePath IDs
    @Published var alertMessage: String?
    @Published var showCleanupComplete = false
    @Published var lastFreedSpace: Int64 = 0

    private let service = CacheCleanerService.shared
    private var scanTask: Task<Void, Never>?
    private var progressTask: Task<Void, Never>?

    var totalSelectedSize: Int64 {
        var total: Int64 = 0
        for category in categories {
            for path in category.paths {
                if selection.contains(path.id) {
                    total += path.size
                }
            }
        }
        return total
    }

    init() {
        // Service 不再发布状态，所有状态由 ViewModel 管理
    }

    func scan() {
        guard !isScanning else { return }
        isScanning = true
        scanProgress = ""
        categories = []

        progressTask?.cancel()
        progressTask = Task {
            let stream = await service.progressStream()
            for await progress in stream {
                if Task.isCancelled { break }
                await MainActor.run { self.scanProgress = progress }
            }
        }

        scanTask?.cancel()
        scanTask = Task {
            let results = await service.scanCaches()
            if !Task.isCancelled {
                await MainActor.run {
                    self.categories = results
                    self.isScanning = false
                    self.scanProgress = ""
                    self.progressTask?.cancel()
                }
                self.selectAllSafe()
            }
        }
    }

    func stopScan() {
        scanTask?.cancel()
        progressTask?.cancel()
        Task { await service.cancelScan() }
        isScanning = false
        scanProgress = ""
    }

    func cleanSelected() {
        guard !selection.isEmpty else { return }

        isCleaning = true

        // Collect selected paths
        var pathsToClean: [CachePath] = []
        for category in categories {
            for path in category.paths {
                if selection.contains(path.id) {
                    pathsToClean.append(path)
                }
            }
        }

        if Self.verbose {
            let size = pathsToClean.reduce(0 as Int64) { $0 + $1.size }
            DiskManagerPlugin.logger.info("\(self.t)开始清理 \(pathsToClean.count) 个路径，预估 \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))")
        }

        Task {
            do {
                let freed = try await service.cleanup(paths: pathsToClean)
                if Self.verbose {
                    DiskManagerPlugin.logger.info("\(self.t)清理完成，释放 \(ByteCountFormatter.string(fromByteCount: freed, countStyle: .file))")
                }
                await MainActor.run {
                    self.lastFreedSpace = freed
                    self.showCleanupComplete = true
                    self.selection.removeAll() // Clear selection
                    self.isCleaning = false
                }
                // 重新扫描以更新状态
                self.scan()
            } catch {
                await MainActor.run {
                    DiskManagerPlugin.logger.error("\(self.t)清理失败：\(error.localizedDescription)")
                    self.alertMessage = String(localized: "Cleanup error: \(error.localizedDescription)")
                    self.isCleaning = false
                }
            }
        }
    }
    
    func selectAllSafe() {
        var newSelection = Set<UUID>()
        for category in categories {
            if category.safetyLevel == .safe {
                for path in category.paths {
                    newSelection.insert(path.id)
                }
            }
        }
        selection = newSelection
    }
    
    func toggleSelection(for path: CachePath) {
        if selection.contains(path.id) {
            selection.remove(path.id)
        } else {
            selection.insert(path.id)
        }
    }
    
    func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
