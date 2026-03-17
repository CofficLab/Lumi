import Foundation
import Combine
import OSLog
import MagicKit

@MainActor
class CacheCleanerViewModel: ObservableObject, SuperLog {
    nonisolated static let emoji = "🗑️"
    nonisolated static let verbose = true
    @Published var categories: [CacheCategory] = []
    @Published var isScanning = false
    @Published var isCleaning = false
    @Published var scanProgress: String = ""
    @Published var selection: Set<UUID> = [] // Selected CachePath IDs
    @Published var alertMessage: String?
    @Published var showCleanupComplete = false
    @Published var lastFreedSpace: Int64 = 0
    
    private var cancellables = Set<AnyCancellable>()
    
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
        CacheCleanerService.shared.$categories
            .receive(on: RunLoop.main)
            .assign(to: \.categories, on: self)
            .store(in: &cancellables)
            
        CacheCleanerService.shared.$isScanning
            .receive(on: RunLoop.main)
            .assign(to: \.isScanning, on: self)
            .store(in: &cancellables)
            
        CacheCleanerService.shared.$scanProgress
            .receive(on: RunLoop.main)
            .assign(to: \.scanProgress, on: self)
            .store(in: &cancellables)
    }
    
    func scan() {
        if Self.verbose {
            os_log("\(self.t)开始扫描缓存")
        }
        Task {
            await CacheCleanerService.shared.scanCaches()
            if Self.verbose {
                os_log("\(self.t)缓存扫描完成，\(self.categories.count) 个分类")
            }
            // Select all Safe level by default
            selectAllSafe()
        }
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
            os_log("\(self.t)开始清理 \(pathsToClean.count) 个路径，预估 \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))")
        }
        
        Task {
            do {
                let freed = try await CacheCleanerService.shared.cleanup(paths: pathsToClean)
                if Self.verbose {
                    os_log("\(self.t)清理完成，释放 \(ByteCountFormatter.string(fromByteCount: freed, countStyle: .file))")
                }
                self.lastFreedSpace = freed
                self.showCleanupComplete = true
                self.selection.removeAll() // Clear selection
            } catch {
                os_log(.error, "\(self.t)清理失败：\(error.localizedDescription)")
                self.alertMessage = String(localized: "Cleanup error: \(error.localizedDescription)")
            }
            self.isCleaning = false
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
