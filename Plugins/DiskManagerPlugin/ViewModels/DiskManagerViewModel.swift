import Foundation
import Combine

@MainActor
class DiskManagerViewModel: ObservableObject {
    @Published var diskUsage: DiskUsage?
    @Published var largeFiles: [FileItem] = []
    @Published var isScanning = false
    @Published var scanPath: String = FileManager.default.homeDirectoryForCurrentUser.path
    @Published var currentScanningPath: String = ""
    @Published var errorMessage: String?
    
    private var scanTask: Task<Void, Never>?
    
    func refreshDiskUsage() {
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
            }
        }
    }
    
    func stopScan() {
        scanTask?.cancel()
        isScanning = false
        currentScanningPath = ""
    }
    
    func deleteFile(_ item: FileItem) {
        do {
            try DiskService.shared.deleteFile(at: item.url)
            largeFiles.removeAll { $0.id == item.id }
            refreshDiskUsage()
        } catch {
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
