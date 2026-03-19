import Combine
import Foundation
import MagicKit
@MainActor
final class DirectoryTreeViewModel: ObservableObject, SuperLog {
    nonisolated static let emoji = "📁"
    nonisolated static let verbose = true

    @Published var rootEntries: [DirectoryEntry] = []
    @Published var isScanning = false
    @Published var scanProgress: ScanProgress?
    @Published var errorMessage: String?

    private let service = DirectoryTreeService.shared
    private var scanTask: Task<Void, Never>?
    private var progressTask: Task<Void, Never>?

    private let scanPath: String = FileManager.default.homeDirectoryForCurrentUser.path

    func startScan() {
        guard !isScanning else { return }

        if Self.verbose {
            DiskManagerPlugin.logger.info("\(self.t)开始分析目录结构：\((self.scanPath as NSString).lastPathComponent)")
        }

        isScanning = true
        rootEntries = []
        scanProgress = nil
        errorMessage = nil

        progressTask?.cancel()
        progressTask = Task {
            let stream = await service.progressStream()
            for await progress in stream {
                if Task.isCancelled { break }
                self.scanProgress = progress
            }
        }

        scanTask?.cancel()
        scanTask = Task {
            do {
                let entries = try await self.service.scanDirectoryTree(atPath: self.scanPath)
                if !Task.isCancelled {
                    await MainActor.run {
                        self.rootEntries = entries
                        self.isScanning = false
                        self.scanProgress = nil
                        self.progressTask?.cancel()
                    }
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        self.errorMessage = error.localizedDescription
                        self.isScanning = false
                        self.scanProgress = nil
                        self.progressTask?.cancel()
                    }
                }
            }
        }
    }

    func stopScan() {
        if Self.verbose {
            DiskManagerPlugin.logger.info("\(self.t)停止分析目录结构")
        }
        scanTask?.cancel()
        progressTask?.cancel()
        Task { await service.cancelScan() }
        isScanning = false
        scanProgress = nil
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

