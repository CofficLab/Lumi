import Foundation
import Combine
import OSLog
import MagicKit

@MainActor
class DiskManagerViewModel: ObservableObject, SuperLog {
    nonisolated static let emoji = "💿"
    nonisolated static let verbose = false

    @Published var diskUsage: DiskUsage?
    @Published var largeFiles: [LargeFileEntry] = []
    @Published var rootEntries: [DirectoryEntry] = [] // Directory tree root nodes
    @Published var isScanning = false
    @Published var scanPath: String = FileManager.default.homeDirectoryForCurrentUser.path
    @Published var scanProgress: ScanProgress?
    @Published var errorMessage: String?

    private var scanTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Subscribe to service progress
        DiskService.shared.$currentScan
            .receive(on: RunLoop.main)
            .assign(to: \.scanProgress, on: self)
            .store(in: &cancellables)
    }

    func refreshDiskUsage() {
        if Self.verbose {
            os_log("\(self.t)Refresh disk usage")
        }
        Task {
            self.diskUsage = await DiskService.shared.getDiskUsage()
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
            os_log("\(self.t)Start scan: \(url.path)")
        }

        isScanning = true
        largeFiles = []
        rootEntries = []
        errorMessage = nil

        scanTask = Task {
            try? await TaskService.shared.run(title: "Disk Scan: \(url.lastPathComponent)", priority: .userInitiated) { progressCallback in
                // Create a separate task to monitor DiskService progress and update TaskService
                let monitorTask = Task { @MainActor in
                    for await progress in DiskService.shared.$currentScan.values {
                        if progress != nil {
                            // Estimate progress based on some heuristic or just keep it active
                            progressCallback(0.5) // Indeterminate
                        }
                    }
                }
                
                do {
                    let result = try await DiskService.shared.scan(url.path)
                    monitorTask.cancel()
                    progressCallback(1.0)
                    
                    if !Task.isCancelled {
                        await MainActor.run {
                            self.largeFiles = result.largeFiles
                            self.rootEntries = result.entries
                            self.isScanning = false
                            if Self.verbose {
                                os_log("\(self.t)Scan completed, found \(result.largeFiles.count) large files")
                            }
                        }
                    }
                } catch {
                    monitorTask.cancel()
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
            os_log("\(self.t)Stop scan")
        }
        scanTask?.cancel()
        DiskService.shared.cancelScan()
        isScanning = false
    }

    func deleteFile(_ item: LargeFileEntry) {
        if Self.verbose {
            os_log("\(self.t)Delete file: \(item.name)")
        }
        Task {
            do {
                let url = URL(fileURLWithPath: item.path)
                try await DiskService.shared.deleteFile(at: url)
                await MainActor.run {
                    self.largeFiles.removeAll { $0.id == item.id }
                    self.refreshDiskUsage()
                }
            } catch {
                await MainActor.run {
                    os_log(.error, "\(self.t)Failed to delete file: \(error.localizedDescription)")
                    self.errorMessage = "Delete failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func revealInFinder(_ item: LargeFileEntry) {
        let url = URL(fileURLWithPath: item.path)
        DiskService.shared.revealInFinder(url: url)
    }
    
    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        return formatter
    }()
    
    func formatBytes(_ bytes: Int64) -> String {
        return Self.byteFormatter.string(fromByteCount: bytes)
    }
}
