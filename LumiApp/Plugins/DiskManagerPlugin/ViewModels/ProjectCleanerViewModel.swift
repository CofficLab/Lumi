import Foundation
import Combine
import SwiftUI

@MainActor
final class ProjectCleanerViewModel: ObservableObject {
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
        
        Task {
            do {
                try await ProjectCleanerService.shared.cleanProjects(itemsToClean)
                
                await MainActor.run {
                    self.isCleaning = false
                    self.showCleanConfirmation = false
                    self.scanProjects() // Rescan to update status
                }
            } catch {
                await MainActor.run {
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
