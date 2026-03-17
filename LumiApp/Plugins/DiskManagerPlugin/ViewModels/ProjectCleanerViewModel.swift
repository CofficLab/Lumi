import Foundation
import OSLog
import MagicKit
import SwiftUI

@MainActor
final class ProjectCleanerViewModel: ObservableObject, SuperLog {
    nonisolated static let emoji = "📋"
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

    private let service = ProjectCleanerService.shared

    init() {
        // Service 不再发布状态，所有状态由 ViewModel 管理
    }

    func scanProjects() async {
        if Self.verbose {
            os_log("\(self.t)开始扫描项目")
        }

        await MainActor.run {
            self.isScanning = true
            self.selectedItemIds = []
        }

        let result = await service.scanProjects()

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

    func toggleSelection(_ id: UUID) {
        if selectedItemIds.contains(id) {
            selectedItemIds.remove(id)
        } else {
            selectedItemIds.insert(id)
        }
    }

    func cleanSelected() {
        guard !selectedItemIds.isEmpty else { return }

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
            let sizeString = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            os_log("\(self.t)开始清理 \(itemsToClean.count) 项，预估 \(sizeString)")
        }

        Task {
            await MainActor.run { self.isCleaning = true }

            do {
                try await service.cleanProjects(itemsToClean)

                if Self.verbose {
                    os_log("\(self.t)项目清理完成")
                }

                await scanProjects() // Rescan to update status
            } catch {
                os_log(.error, "\(self.t)项目清理失败：\(error.localizedDescription)")
                // TODO: Show error
            }

            await MainActor.run { self.isCleaning = false }
        }
    }

    func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
