import Foundation
import AppKit
import OSLog
import MagicKit

struct DiskUsage {
    let total: Int64
    let used: Int64
    let available: Int64

    var usedPercentage: Double {
        return total > 0 ? Double(used) / Double(total) : 0
    }
}

struct FileItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let size: Int64
    let modificationDate: Date

    var name: String { url.lastPathComponent }
    var path: String { url.path }
    var icon: NSImage { NSWorkspace.shared.icon(forFile: path) }
}

class DiskService: SuperLog {
    static let emoji = "💽"
    static let verbose = true

    static let shared = DiskService()

    private init() {
        if Self.verbose {
            os_log("\(self.t)磁盘服务已初始化")
        }
    }

    func getDiskUsage() -> DiskUsage? {
        let fileURL = URL(fileURLWithPath: "/")
        do {
            let values = try fileURL.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey])
            if let total = values.volumeTotalCapacity, let available = values.volumeAvailableCapacity {
                let used = Int64(total) - Int64(available)
                if Self.verbose {
                    let percentage = Double(used) / Double(total) * 100
                    os_log("\(self.t)获取磁盘使用情况: \(String(format: "%.1f", percentage))%")
                }
                return DiskUsage(total: Int64(total), used: used, available: Int64(available))
            }
        } catch {
            os_log(.error, "\(self.t)获取磁盘使用情况失败: \(error.localizedDescription)")
        }
        return nil
    }
    
    func scanLargeFiles(in directory: URL, minSize: Int64 = 100 * 1024 * 1024, limit: Int = 50, progressHandler: @escaping (String) -> Void) async -> [FileItem] {
        return await withTaskGroup(of: [FileItem].self) { group in
            var files: [FileItem] = []
            
            let fileManager = FileManager.default
            let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey, .isPackageKey]
            let options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles, .skipsPackageDescendants]
            
            if let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: keys, options: options) {
                var batch: [FileItem] = []
                var count = 0
                
                for case let fileURL as URL in enumerator {
                    // Check cancellation periodically
                    if Task.isCancelled { break }
                    
                    count += 1
                    if count % 100 == 0 {
                        progressHandler(fileURL.path)
                    }
                    
                    do {
                        let resourceValues = try fileURL.resourceValues(forKeys: Set(keys))
                        
                        // Skip directories unless they are packages
                        if let isDirectory = resourceValues.isDirectory, isDirectory {
                            if let isPackage = resourceValues.isPackage, !isPackage {
                                continue
                            }
                        }
                        
                        if let size = resourceValues.fileSize, Int64(size) > minSize {
                            let date = resourceValues.contentModificationDate ?? Date()
                            batch.append(FileItem(url: fileURL, size: Int64(size), modificationDate: date))
                        }
                    } catch {
                        continue
                    }
                }
                files.append(contentsOf: batch)
            }
            
            return files.sorted { $0.size > $1.size }.prefix(limit).map { $0 }
        }
    }
    
    func deleteFile(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }
    
    func revealInFinder(url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
