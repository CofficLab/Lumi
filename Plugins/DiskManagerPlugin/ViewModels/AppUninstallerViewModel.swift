import Foundation
import Combine
import SwiftUI

class AppUninstallerViewModel: ObservableObject {
    @Published var apps: [ApplicationInfo] = []
    @Published var selectedApp: ApplicationInfo?
    @Published var relatedFiles: [RelatedFile] = []
    @Published var selectedFileIds: Set<UUID> = []
    
    @Published var isScanningApps = false
    @Published var isScanningFiles = false
    @Published var isDeleting = false
    @Published var showDeleteConfirmation = false
    
    private var cancellables = Set<AnyCancellable>()
    
    var totalSelectedSize: Int64 {
        relatedFiles.filter { selectedFileIds.contains($0.id) }
            .reduce(0) { $0 + $1.size }
    }
    
    func scanApps() {
        isScanningApps = true
        Task {
            let result = await AppUninstallerService.shared.scanApps()
            await MainActor.run {
                self.apps = result
                self.isScanningApps = false
            }
        }
    }
    
    func selectApp(_ app: ApplicationInfo) {
        selectedApp = app
        relatedFiles = []
        selectedFileIds = []
        scanRelatedFiles(for: app)
    }
    
    private func scanRelatedFiles(for app: ApplicationInfo) {
        isScanningFiles = true
        Task {
            let result = await AppUninstallerService.shared.scanRelatedFiles(for: app)
            await MainActor.run {
                self.relatedFiles = result
                // 默认全选
                self.selectedFileIds = Set(result.map { $0.id })
                self.isScanningFiles = false
            }
        }
    }
    
    func toggleFileSelection(_ id: UUID) {
        if selectedFileIds.contains(id) {
            selectedFileIds.remove(id)
        } else {
            selectedFileIds.insert(id)
        }
    }
    
    func deleteSelectedFiles() {
        guard !selectedFileIds.isEmpty else { return }
        isDeleting = true
        
        let filesToDelete = relatedFiles.filter { selectedFileIds.contains($0.id) }
        
        Task {
            do {
                try await AppUninstallerService.shared.deleteFiles(filesToDelete)
                
                await MainActor.run {
                    self.isDeleting = false
                    self.showDeleteConfirmation = false
                    // 刷新或移除已删除项
                    // 如果删除了主 App，则取消选择
                    if let app = self.selectedApp, self.selectedFileIds.contains(where: { id in
                        if let file = self.relatedFiles.first(where: { $0.id == id }) {
                            return file.type == .app
                        }
                        return false
                    }) {
                        self.selectedApp = nil
                        self.relatedFiles = []
                        // 从列表移除 App
                        self.apps.removeAll { $0.id == app.id }
                    } else {
                        // 仅移除了部分文件
                        self.scanRelatedFiles(for: self.selectedApp!)
                    }
                }
            } catch {
                await MainActor.run {
                    self.isDeleting = false
                    // TODO: Show error
                }
            }
        }
    }
}
