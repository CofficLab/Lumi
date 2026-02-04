import Foundation
import Combine
import SwiftUI

class ProjectCleanerViewModel: ObservableObject {
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
        isScanning = true
        selectedItemIds = []
        Task {
            let result = await ProjectCleanerService.shared.scanProjects()
            await MainActor.run {
                self.projects = result
                self.isScanning = false
                // 默认全选所有可清理项
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
        
        Task {
            do {
                try await ProjectCleanerService.shared.cleanProjects(itemsToClean)
                
                await MainActor.run {
                    self.isCleaning = false
                    self.showCleanConfirmation = false
                    self.scanProjects() // 重新扫描以更新状态
                }
            } catch {
                await MainActor.run {
                    self.isCleaning = false
                    // TODO: Show error
                }
            }
        }
    }
}
