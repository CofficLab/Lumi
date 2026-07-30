import Foundation
import SuperLogKit
import Combine

final class DiskManagerScanTaskHolder: @unchecked Sendable {
    var scanTask: Task<Void, Never>?
    var progressTask: Task<Void, Never>?

    func cancel() {
        scanTask?.cancel()
        scanTask = nil
        cancelProgress()
    }

    func cancelProgress() {
        progressTask?.cancel()
        progressTask = nil
    }
}

@MainActor
class DiskManagerViewModel: ObservableObject, SuperLog {
    nonisolated static let emoji = "💿"
    nonisolated static let verbose: Bool = true
    @Published var diskUsage: DiskUsage?
    @Published var largeFiles: [LargeFileEntry] = []
    @Published var rootEntries: [DirectoryEntry] = [] // Directory tree root nodes
    @Published var isScanning = false
    @Published var scanPath: String = FileManager.default.homeDirectoryForCurrentUser.path
    @Published var scanProgress: ScanProgress?
    @Published var errorMessage: String?

    private nonisolated let scanTasks = DiskManagerScanTaskHolder()
    private let service = DiskService.shared

    deinit {
        scanTasks.cancel()
        Task { await DiskService.shared.cancelScan() }
    }

    func refreshDiskUsage() {
        if Self.verbose {
            if DiskManagerPlugin.verbose {
                            DiskManagerPlugin.logger.info("\(self.t)刷新磁盘使用情况")
            }
        }
        Task {
            self.diskUsage = await service.getDiskUsage()
        }
    }
    
    func startScan() {
        guard !isScanning else { return }

        let url = Self.scanURL(from: scanPath)

        if Self.verbose {
            if DiskManagerPlugin.verbose {
                            DiskManagerPlugin.logger.info("\(self.t)开始扫描：\((url.path as NSString).lastPathComponent)")
            }
        }

        isScanning = true
        largeFiles = []
        rootEntries = []
        errorMessage = nil

        scanTasks.scanTask = Task {
            do {
                let result = try await self.service.scan(url.path)

                if !Task.isCancelled {
                    await MainActor.run {
                        self.largeFiles = result.largeFiles
                        self.rootEntries = result.entries
                        self.isScanning = false
                        if Self.verbose {
                            if DiskManagerPlugin.verbose {
                                                                    DiskManagerPlugin.logger.info("\(self.t)扫描完成，发现 \(result.largeFiles.count) 个大文件")
                            }
                        }
                    }
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        self.errorMessage = error.localizedDescription
                        self.isScanning = false
                    }
                }
            }
        }
    }

    nonisolated static func scanURL(from path: String) -> URL {
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedPath.hasPrefix("/") {
            return URL(fileURLWithPath: trimmedPath)
        }
        if trimmedPath == "~" || trimmedPath.hasPrefix("~/") {
            return URL(fileURLWithPath: (trimmedPath as NSString).expandingTildeInPath)
        }
        if let url = URL(string: trimmedPath), url.isFileURL {
            return url
        }
        if trimmedPath.lowercased().hasPrefix("file://") {
            let rawPath = String(trimmedPath.dropFirst("file://".count))
            let path = rawPath
                .replacingOccurrences(of: "^localhost", with: "", options: .regularExpression)
                .removingPercentEncoding ?? rawPath
            return URL(fileURLWithPath: path)
        }
        return URL(fileURLWithPath: trimmedPath)
    }

    func stopScan() {
        if Self.verbose {
            if DiskManagerPlugin.verbose {
                            DiskManagerPlugin.logger.info("\(self.t)停止扫描")
            }
        }
        cancelScanResources()
        isScanning = false
    }

    private func cancelScanResources() {
        scanTasks.cancel()
        let service = service
        Task { await service.cancelScan() }
    }

    func deleteFile(_ item: LargeFileEntry) {
        if Self.verbose {
            if DiskManagerPlugin.verbose {
                            DiskManagerPlugin.logger.info("\(self.t)删除文件：\(item.name)")
            }
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
                    if DiskManagerPlugin.verbose {
                                            DiskManagerPlugin.logger.error("\(self.t)删除文件失败：\(error.localizedDescription)")
                    }
                    self.errorMessage = PluginDiskManagerLocalization.string("Delete failed: \(error.localizedDescription)")
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
