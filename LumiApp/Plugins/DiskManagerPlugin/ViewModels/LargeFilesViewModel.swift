import Combine
import Foundation
import MagicKit
@MainActor
final class LargeFilesViewModel: ObservableObject, SuperLog {
    nonisolated static let emoji = "📄"
    nonisolated static let verbose = true

    @Published var largeFiles: [LargeFileEntry] = []
    @Published var isScanning = false
    @Published var scanProgress: ScanProgress?
    @Published var errorMessage: String?

    private let service = LargeFilesService.shared
    private var scanTask: Task<Void, Never>?
    private var progressTask: Task<Void, Never>?
    private var progressReceivedCount: Int = 0
    private var lastProgressLogAt: Date = .distantPast

    private let scanPath: String = FileManager.default.homeDirectoryForCurrentUser.path

    func startScan() {
        guard !isScanning else { return }

        if Self.verbose {
            DiskManagerPlugin.logger.info("\(self.t)开始扫描大文件：\((self.scanPath as NSString).lastPathComponent)")
        }

        isScanning = true
        largeFiles = []
        scanProgress = nil
        errorMessage = nil
        progressReceivedCount = 0
        lastProgressLogAt = .distantPast

        progressTask?.cancel()
        progressTask = Task {
            let stream = await service.progressStream()
            for await progress in stream {
                if Task.isCancelled { break }
                self.scanProgress = progress
                self.progressReceivedCount += 1
                if Self.verbose {
                    let now = Date()
                    if self.progressReceivedCount == 1 || now.timeIntervalSince(self.lastProgressLogAt) >= 2.0 {
                        self.lastProgressLogAt = now
                        DiskManagerPlugin.logger.info(
                            "\(self.t)[VM] progress recv#\(self.progressReceivedCount) files=\(progress.scannedFiles) dirs=\(progress.scannedDirectories) bytes=\(progress.scannedBytes) path=\(progress.currentPath)"
                        )
                    }
                }
            }
        }

        scanTask?.cancel()
        scanTask = Task {
            try? await TaskService.shared.run(
                title: String(localized: "Disk Scan: \(URL(fileURLWithPath: scanPath).lastPathComponent)"),
                priority: .userInitiated
            ) { progressCallback in
                do {
                    let files = try await self.service.scanLargeFiles(atPath: self.scanPath)
                    progressCallback(1.0)

                    if !Task.isCancelled {
                        await MainActor.run {
                            self.largeFiles = files
                            self.isScanning = false
                            self.scanProgress = nil
                            self.progressTask?.cancel()
                            if Self.verbose {
                                DiskManagerPlugin.logger.info("\(self.t)大文件扫描完成，发现 \(files.count) 个大文件")
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
            DiskManagerPlugin.logger.info("\(self.t)停止扫描大文件")
        }
        scanTask?.cancel()
        progressTask?.cancel()
        Task { await service.cancelScan() }
        isScanning = false
        scanProgress = nil
    }

    func deleteFile(_ item: LargeFileEntry) {
        if Self.verbose {
            DiskManagerPlugin.logger.info("\(self.t)删除大文件：\(item.name)")
        }
        Task {
            do {
                try await service.deleteFile(atPath: item.path)
                await MainActor.run {
                    self.largeFiles.removeAll { $0.id == item.id }
                }
            } catch {
                await MainActor.run {
                    DiskManagerPlugin.logger.error("\(self.t)删除文件失败：\(error.localizedDescription)")
                    self.errorMessage = String(localized: "Delete failed: \(error.localizedDescription)")
                }
            }
        }
    }

    func revealInFinder(_ item: LargeFileEntry) {
        service.revealInFinder(path: item.path)
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
