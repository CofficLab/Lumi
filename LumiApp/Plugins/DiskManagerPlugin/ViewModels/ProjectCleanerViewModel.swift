import Foundation
import Combine
import OSLog
import MagicKit
import SwiftUI

@MainActor
final class ProjectCleanerViewModel: ObservableObject, SuperLog {
    nonisolated static let emoji = "📁"
    nonisolated static let verbose = true
    @Published var projects: [ProjectInfo] = []
    @Published var selectedItemIds: Set<UUID> = []
    
    @Published var isScanning = false
    @Published var isCleaning = false
    @Published var showCleanConfirmation = false
    
    var totalSelectedSize: Int64 {
        var total: Int64 = 0
        for project in projects {
            for item in project.cleanableItems {
                if selectedItemIds.contains(item.id) {
                    total += item.size
                }
            }
        }
        return total
    }
    
    func scanProjects() {
        if Self.verbose {
            os_log("\(self.t)开始扫描项目")
        }
        isScanning = true
        selectedItemIds = []
        Task {
            let result = await ProjectCleanerService.shared.scanProjects()
            await MainActor.run {
                self.projects = result
                self.isScanning = false
                if Self.verbose {
                    os_log("\(self.t)项目扫描完成：\(result.count) 个项目")
                }
                // Select all cleanable items by default
                for project in result {
                    for item in project.cleanableItems {
                        self.selectedItemIds.insert(item.id)
                    }
                }
            }
        }
    }
    
    func toggleSelection(_ id: UUID) {
        if selectedItemIds.contains(id) {
            selectedItemIds.remove(id)
        } else {
            selectedItemIds.insert(id)
        }
    }
    
    func cleanSelected() {
        guard !selectedItemIds.isEmpty else { return }
        isCleaning = true
        
        var itemsToClean: [CleanableItem] = []
        for project in projects {
            for item in project.cleanableItems {
                if selectedItemIds.contains(item.id) {
                    itemsToClean.append(item)
                }
            }
        }
        
        if Self.verbose {
            let size = itemsToClean.reduce(0 as Int64) { $0 + $1.size }
            os_log("\(self.t)开始清理 \(itemsToClean.count) 项，预估 \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))")
        }
        
        Task {
            do {
                try await ProjectCleanerService.shared.cleanProjects(itemsToClean)
                
                await MainActor.run {
                    if Self.verbose {
                        os_log("\(self.t)项目清理完成")
                    }
                    self.isCleaning = false
                    self.showCleanConfirmation = false
                    self.scanProjects() // Rescan to update status
                }
            } catch {
                await MainActor.run {
                    os_log(.error, "\(self.t)项目清理失败：\(error.localizedDescription)")
                    self.isCleaning = false
                    // TODO: Show error
                }
            }
        }
    }
    
    func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
