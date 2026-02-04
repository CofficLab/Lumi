import Foundation
import AppKit

// MARK: - 磁盘使用情况

struct DiskUsage: Codable {
    let total: Int64
    let used: Int64
    let available: Int64
    
    var usedPercentage: Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total)
    }
}

// MARK: - 目录扫描模型

struct DirectoryEntry: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let path: String
    let size: Int64
    let isDirectory: Bool
    let lastAccessed: Date
    let modificationDate: Date
    var children: [DirectoryEntry]?  // nil 表示未扫描或非目录
    
    var isScanned: Bool { children != nil }
    var depth: Int { path.components(separatedBy: "/").count }
    
    // Helper to get icon
    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: path)
    }
    
    // Codable implementation to skip NSImage
    enum CodingKeys: String, CodingKey {
        case id, name, path, size, isDirectory, lastAccessed, modificationDate, children
    }
}

// MARK: - 大文件模型

struct LargeFileEntry: Identifiable, Hashable, Codable, Comparable {
    let id: String
    let name: String
    let path: String
    let size: Int64
    let modificationDate: Date
    let fileType: FileType
    
    // Comparable implementation
    static func < (lhs: LargeFileEntry, rhs: LargeFileEntry) -> Bool {
        return lhs.size < rhs.size
    }
    
    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: path)
    }
    
    enum FileType: String, Codable {
        case document, image, video, audio, archive, code, other
        
        static func from(extension ext: String) -> FileType {
            let lowerExt = ext.lowercased()
            switch lowerExt {
            case "jpg", "jpeg", "png", "gif", "heic", "svg", "webp": return .image
            case "mp4", "mov", "avi", "mkv", "webm": return .video
            case "mp3", "wav", "aac", "flac", "m4a": return .audio
            case "zip", "rar", "7z", "tar", "gz": return .archive
            case "swift", "c", "cpp", "h", "py", "js", "ts", "html", "css", "json", "xml", "md": return .code
            case "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "rtf": return .document
            default: return .other
            }
        }
    }
    
    // Codable implementation to skip NSImage
    enum CodingKeys: String, CodingKey {
        case id, name, path, size, modificationDate, fileType
    }
}

// MARK: - 扫描结果

struct ScanResult {
    let entries: [DirectoryEntry]
    let largeFiles: [LargeFileEntry]
    let totalSize: Int64
    let totalFiles: Int
    let scanDuration: TimeInterval
    let scannedAt: Date
}

// MARK: - 扫描进度

struct ScanProgress {
    let path: String
    let currentPath: String
    let scannedFiles: Int
    let scannedDirectories: Int
    let scannedBytes: Int64
    let startTime: Date

    var duration: TimeInterval {
        Date().timeIntervalSince(startTime)
    }

    var filesPerSecond: Double {
        duration > 0 ? Double(scannedFiles) / duration : 0
    }
}

// MARK: - 最大堆 (用于 Top N 大文件)

struct MaxHeap<Element: Hashable & Comparable> {
    private var heap: [Element] = []
    private let capacity: Int
    
    init(capacity: Int) {
        self.capacity = capacity
    }

    mutating func insert(_ element: Element) {
        if heap.count < capacity {
            heap.append(element)
            // 如果使用最小堆来维护Top N最大的元素（堆顶是最小的，新元素比堆顶大则替换），这里应该是最小堆逻辑？
            // 实际上，如果我们要维护 Top N *最大* 的文件，我们需要一个能够快速访问 *当前Top N中最小元素* 的结构。
            // 如果新元素比这个最小元素大，就替换它。
            // 所以我们需要一个 *最小堆* (MinHeap) 来存储 Top N 个最大的元素。
            // 堆顶是这 N 个里最小的。任何比堆顶大的元素都有资格进入 Top N。
            
            // 但是 ROADMAP 里写的是 MaxHeap。这可能是笔误，或者是想用 MaxHeap 存所有元素然后取 Top N？
            // 考虑到内存效率，维护一个固定大小的 MinHeap 是标准的 Top K 问题解法。
            // 这里我将实现一个固定容量的容器，保留最大的 N 个元素。
            // 为了方便，可以直接用数组排序，对于 N=100 来说性能足够好。
            // 或者严格实现 MinHeap。
            
            // 让我们修正为：维护 Top N Largest Items -> 需要 Min Heap 剔除最小的。
            // 但为了简单和正确性，对于 N=100，直接 append 然后 sort dropLast 也是可以的，或者插入排序。
            // 这里为了遵循 ROADMAP 的精神，我用简单高效的方式：插入并保持有序。
            
            heap.append(element)
            heap.sort() // 升序，last 是最大的
            if heap.count > capacity {
                heap.removeFirst() // 移除最小的
            }
        } else {
            // heap is full.
            // heap.first is the smallest of the top N.
            if let min = heap.first, element > min {
                heap[0] = element
                heap.sort() // 重新排序
            }
        }
    }

    var elements: [Element] { heap.sorted(by: >) } // 返回降序
}
