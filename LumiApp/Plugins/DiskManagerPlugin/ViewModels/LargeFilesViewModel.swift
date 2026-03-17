import Foundation
import Combine
import OSLog
import MagicKit

@MainActor
final class LargeFilesViewModel: ObservableObject, SuperLog {
    nonisolated static let emoji = "📄"
    nonisolated static let verbose = true

    @Published var largeFiles: [LargeFileEntry] = []
    @Published var isScanning = false
    @Published var scanProgress: ScanProgress?
    @Published var errorMessage: String?

    private let service = DiskService.shared
    private var scanTask: Task<Void, Never>?
    private var progressTask: Task<Void, Never>?

    private let scanPath: String = FileManager.default.homeDirectoryForCurrentUser.path

    func startScan() {
        guard !isScanning else { return }

        if Self.verbose {
            os_log("\(self.t)开始扫描大文件：\((self.scanPath as NSString).lastPathComponent)")
        }

        isScanning = true
        largeFiles = []
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
            try? await TaskService.shared.run(
                title: String(localized: "Disk Scan: \(URL(fileURLWithPath: scanPath).lastPathComponent)"),
                priority: .userInitiated
            ) { progressCallback in
                do {
                    let result = try await self.service.scan(self.scanPath)
                    progressCallback(1.0)

                    if !Task.isCancelled {
                        await MainActor.run {
                            self.largeFiles = result.largeFiles
                            self.isScanning = false
                            self.scanProgress = nil
                            self.progressTask?.cancel()
                            if Self.verbose {
                                os_log("\(self.t)大文件扫描完成，发现 \(result.largeFiles.count) 个大文件")
                            }
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
                        throw error
                    }
                }
            }
        }
    }

    func stopScan() {
        if Self.verbose {
            os_log("\(self.t)停止扫描大文件")
        }
        scanTask?.cancel()
        progressTask?.cancel()
        Task { await service.cancelScan() }
        isScanning = false
        scanProgress = nil
    }

    func deleteFile(_ item: LargeFileEntry) {
        if Self.verbose {
            os_log("\(self.t)删除大文件：\(item.name)")
        }
        Task {
            do {
                let url = URL(fileURLWithPath: item.path)
                try await service.deleteFile(at: url)
                await MainActor.run {
                    self.largeFiles.removeAll { $0.id == item.id }
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
        Self.byteFormatter.string(fromByteCount: bytes)
    }
}

