import Foundation
import Combine
import OSLog
import MagicKit

@MainActor
class DiskManagerViewModel: ObservableObject, SuperLog {
    nonisolated static let emoji = "💿"
    nonisolated static let verbose = true

    @Published var diskUsage: DiskUsage?
    @Published var largeFiles: [LargeFileEntry] = []
    @Published var rootEntries: [DirectoryEntry] = [] // Directory tree root nodes
    @Published var isScanning = false
    @Published var scanPath: String = FileManager.default.homeDirectoryForCurrentUser.path
    @Published var scanProgress: ScanProgress?
    @Published var errorMessage: String?

    private var scanTask: Task<Void, Never>?
    private let service = DiskService.shared

    func refreshDiskUsage() {
        if Self.verbose {
            os_log("\(self.t)刷新磁盘使用情况")
        }
        Task {
            self.diskUsage = await service.getDiskUsage()
        }
    }
    
    func startScan() {
        guard !isScanning else { return }

        let url: URL
        if scanPath.hasPrefix("/") {
             url = URL(fileURLWithPath: scanPath)
        } else if let validUrl = URL(string: scanPath) {
             url = validUrl
        } else {
             // Fallback
             url = URL(fileURLWithPath: scanPath)
        }

        if Self.verbose {
            os_log("\(self.t)开始扫描：\((url.path as NSString).lastPathComponent)")
        }

        isScanning = true
        largeFiles = []
        rootEntries = []
        errorMessage = nil

        scanTask = Task {
            try? await TaskService.shared.run(title: String(localized: "Disk Scan: \(url.lastPathComponent)"), priority: .userInitiated) { progressCallback in
                // Execute scan directly - progress is managed by ViewModel
                do {
                    let result = try await self.service.scan(url.path)
                    progressCallback(1.0)

                    if !Task.isCancelled {
                        await MainActor.run {
                            self.largeFiles = result.largeFiles
                            self.rootEntries = result.entries
                            self.isScanning = false
                            if Self.verbose {
                                os_log("\(self.t)扫描完成，发现 \(result.largeFiles.count) 个大文件")
                            }
                        }
                    }
                } catch {
                    if !Task.isCancelled {
                        await MainActor.run {
                            self.errorMessage = error.localizedDescription
                            self.isScanning = false
                        }
                        throw error // Propagate to TaskService
                    }
                }
            }
        }
    }

    func stopScan() {
        if Self.verbose {
            os_log("\(self.t)停止扫描")
        }
        scanTask?.cancel()
        Task { await service.cancelScan() }
        isScanning = false
    }

    func deleteFile(_ item: LargeFileEntry) {
        if Self.verbose {
            os_log("\(self.t)删除文件：\(item.name)")
        }
        Task {
            do {
                let url = URL(fileURLWithPath: item.path)
                try await service.deleteFile(at: url)
                await MainActor.run {
                    self.largeFiles.removeAll { $0.id == item.id }
                    self.refreshDiskUsage()
                }
            } catch {
                await MainActor.run {
                    os_log(.error, "\(self.t)删除文件失败：\(error.localizedDescription)")
                    self.errorMessage = String(localized: "Delete failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func revealInFinder(_ item: LargeFileEntry) {
        let url = URL(fileURLWithPath: item.path)
        service.revealInFinder(url: url)
    }

    static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        return formatter
    }()

    func formatBytes(_ bytes: Int64) -> String {
        return Self.byteFormatter.string(fromByteCount: bytes)
    }
}
