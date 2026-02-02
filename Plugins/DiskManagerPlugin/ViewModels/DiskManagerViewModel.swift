import Foundation
import Combine
import OSLog
import MagicKit

@MainActor
class DiskManagerViewModel: ObservableObject, SuperLog {
    static let emoji = "💿"
    static let verbose = false

    @Published var diskUsage: DiskUsage?
    @Published var largeFiles: [FileItem] = []
    @Published var isScanning = false
    @Published var scanPath: String = FileManager.default.homeDirectoryForCurrentUser.path
    @Published var currentScanningPath: String = ""
    @Published var errorMessage: String?

    private var scanTask: Task<Void, Never>?

    func refreshDiskUsage() {
        if Self.verbose {
            os_log("\(self.t)刷新磁盘使用情况")
        }
        self.diskUsage = DiskService.shared.getDiskUsage()
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
            os_log("\(self.t)开始扫描大文件: \(url.path)")
        }

        isScanning = true
        largeFiles = []
        errorMessage = nil

        scanTask = Task {
            let files = await DiskService.shared.scanLargeFiles(in: url) { [weak self] path in
                Task { @MainActor in
                    self?.currentScanningPath = path
                }
            }

            if !Task.isCancelled {
                self.largeFiles = files
                self.isScanning = false
                self.currentScanningPath = ""
                if Self.verbose {
                    os_log("\(self.t)扫描完成，找到 \(files.count) 个大文件")
                }
            }
        }
    }

    func stopScan() {
        if Self.verbose {
            os_log("\(self.t)停止扫描")
        }
        scanTask?.cancel()
        isScanning = false
        currentScanningPath = ""
    }

    func deleteFile(_ item: FileItem) {
        if Self.verbose {
            os_log("\(self.t)删除文件: \(item.name)")
        }
        do {
            try DiskService.shared.deleteFile(at: item.url)
            largeFiles.removeAll { $0.id == item.id }
            refreshDiskUsage()
        } catch {
            os_log(.error, "\(self.t)删除文件失败: \(error.localizedDescription)")
            errorMessage = "删除失败: \(error.localizedDescription)"
        }
    }
    
    func revealInFinder(_ item: FileItem) {
        DiskService.shared.revealInFinder(url: item.url)
    }
    
    func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
