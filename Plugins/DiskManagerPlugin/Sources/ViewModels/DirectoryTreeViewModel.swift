import Combine
import Foundation
import SuperLogKit
@MainActor
final class DirectoryTreeViewModel: ObservableObject, SuperLog {
    nonisolated static let emoji = "📁"
    nonisolated static let verbose: Bool = true
    @Published var rootEntries: [DirectoryEntry] = []
    @Published var isScanning = false
    @Published var scanProgress: ScanProgress?
    @Published var errorMessage: String?

    private let service = DirectoryTreeService.shared
    private nonisolated let scanTasks = DiskManagerScanTaskHolder()

    private let scanPath: String = FileManager.default.homeDirectoryForCurrentUser.path

    deinit {
        scanTasks.cancel()
        Task { await DirectoryTreeService.shared.cancelScan() }
    }

    func startScan() {
        guard !isScanning else { return }

        if Self.verbose {
            if DiskManagerPlugin.verbose {
                            DiskManagerPlugin.logger.info("\(self.t)开始分析目录结构：\((self.scanPath as NSString).lastPathComponent)")
            }
        }

        isScanning = true
        rootEntries = []
        scanProgress = nil
        errorMessage = nil

        scanTasks.cancelProgress()
        scanTasks.progressTask = Task {
            let stream = await service.progressStream()
            for await progress in stream {
                if Task.isCancelled { break }
                self.scanProgress = progress
            }
        }

        scanTasks.scanTask?.cancel()
        scanTasks.scanTask = Task {
            do {
                let entries = try await self.service.scanDirectoryTree(atPath: self.scanPath)
                if !Task.isCancelled {
                    await MainActor.run {
                        self.rootEntries = entries
                        self.isScanning = false
                        self.scanProgress = nil
                        self.scanTasks.cancelProgress()
                    }
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        self.errorMessage = error.localizedDescription
                        self.isScanning = false
                        self.scanProgress = nil
                        self.scanTasks.cancelProgress()
                    }
                }
            }
        }
    }

    func stopScan() {
        if Self.verbose {
            if DiskManagerPlugin.verbose {
                            DiskManagerPlugin.logger.info("\(self.t)停止分析目录结构")
            }
        }
        cancelScanResources()
        isScanning = false
        scanProgress = nil
    }

    private func cancelScanResources() {
        scanTasks.cancel()
        let service = service
        Task { await service.cancelScan() }
    }

    func revealInFinder(_ entry: DirectoryEntry) {
        service.revealInFinder(path: entry.path)
    }

    static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        return formatter
    }()

    func formatBytes(_ bytes: Int64) -> String {
        Self.byteFormatter.string(fromByteCount: bytes)
    }
}
