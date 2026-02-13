import Foundation
import Combine
import OSLog
import MagicKit

@MainActor
class CacheCleanerViewModel: ObservableObject, SuperLog {
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
        Task {
            await CacheCleanerService.shared.scanCaches()
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
        
        Task {
            do {
                let freed = try await CacheCleanerService.shared.cleanup(paths: pathsToClean)
                self.lastFreedSpace = freed
                self.showCleanupComplete = true
                self.selection.removeAll() // Clear selection
            } catch {
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
