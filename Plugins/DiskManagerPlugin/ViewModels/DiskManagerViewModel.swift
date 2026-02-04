import Foundation
import Combine
import OSLog
import MagicKit

@MainActor
class DiskManagerViewModel: ObservableObject, SuperLog {
    static let emoji = "💿"
    static let verbose = false

    @Published var diskUsage: DiskUsage?
    @Published var largeFiles: [LargeFileEntry] = []
    @Published var rootEntries: [DirectoryEntry] = [] // 目录树根节点
    @Published var isScanning = false
    @Published var scanPath: String = FileManager.default.homeDirectoryForCurrentUser.path
    @Published var scanProgress: ScanProgress?
    @Published var errorMessage: String?

    private var scanTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init() {
        // 订阅 Service 的进度
        DiskService.shared.$currentScan
            .receive(on: RunLoop.main)
            .assign(to: \.scanProgress, on: self)
            .store(in: &cancellables)
    }

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
            os_log("\(self.t)开始扫描: \(url.path)")
        }

        isScanning = true
        largeFiles = []
        rootEntries = []
        errorMessage = nil

        scanTask = Task {
            do {
                let result = try await DiskService.shared.scan(url.path)
                
                if !Task.isCancelled {
                    self.largeFiles = result.largeFiles
                    self.rootEntries = result.entries
                    self.isScanning = false
                    if Self.verbose {
                        os_log("\(self.t)扫描完成，找到 \(result.largeFiles.count) 个大文件")
                    }
                }
            } catch {
                if !Task.isCancelled {
                    self.errorMessage = error.localizedDescription
                    self.isScanning = false
                }
            }
        }
    }

    func stopScan() {
        if Self.verbose {
            os_log("\(self.t)停止扫描")
        }
        scanTask?.cancel()
        DiskService.shared.cancelScan()
        isScanning = false
    }

    func deleteFile(_ item: LargeFileEntry) {
        if Self.verbose {
            os_log("\(self.t)删除文件: \(item.name)")
        }
        do {
            let url = URL(fileURLWithPath: item.path)
            try DiskService.shared.deleteFile(at: url)
            largeFiles.removeAll { $0.id == item.id }
            refreshDiskUsage()
        } catch {
            os_log(.error, "\(self.t)删除文件失败: \(error.localizedDescription)")
            errorMessage = "删除失败: \(error.localizedDescription)"
        }
    }
    
    func revealInFinder(_ item: LargeFileEntry) {
        let url = URL(fileURLWithPath: item.path)
        DiskService.shared.revealInFinder(url: url)
    }
    
    func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
