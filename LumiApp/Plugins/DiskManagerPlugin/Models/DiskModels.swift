import Foundation
import AppKit

// MARK: - Disk Usage

struct DiskUsage: Codable, Sendable {
    let total: Int64
    let used: Int64
    let available: Int64
    
    var usedPercentage: Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total)
    }
}

// MARK: - Directory Scan Model

struct DirectoryEntry: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let name: String
    let path: String
    let size: Int64
    let isDirectory: Bool
    let lastAccessed: Date
    let modificationDate: Date
    var children: [DirectoryEntry]?  // nil means not scanned or not a directory
    
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

// MARK: - Large File Model

struct LargeFileEntry: Identifiable, Hashable, Codable, Comparable, Sendable {
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
    
    enum FileType: String, Codable, Sendable {
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

// MARK: - Scan Result

struct ScanResult: Sendable {
    let entries: [DirectoryEntry]
    let largeFiles: [LargeFileEntry]
    let totalSize: Int64
    let totalFiles: Int
    let scanDuration: TimeInterval
    let scannedAt: Date
}

// MARK: - Scan Progress

struct ScanProgress: Sendable {
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

// MARK: - Max Heap (for Top N large files)

struct MaxHeap<Element: Hashable & Comparable & Sendable>: Sendable {
    private var heap: [Element] = []
    private let capacity: Int
    
    init(capacity: Int) {
        self.capacity = capacity
    }

    mutating func insert(_ element: Element) {
        if heap.count < capacity {
            heap.append(element)
            // If using a min-heap to maintain Top N largest elements (root is the smallest, replace if new element is larger), this should be min-heap logic.
            // In fact, if we want to maintain Top N *largest* files, we need a structure that allows fast access to the *smallest element currently in Top N*.
            // If the new element is larger than this smallest element, replace it.
            // So we need a *Min Heap* (MinHeap) to store Top N largest elements.
            // The root is the smallest among these N. Any element larger than the root is eligible to enter Top N.
            
            // However, the ROADMAP says MaxHeap. This might be a typo, or intended to store all elements in a MaxHeap and then take Top N?
            // Considering memory efficiency, maintaining a fixed-size MinHeap is the standard solution for the Top K problem.
            // Here I will implement a fixed-capacity container that keeps the largest N elements.
            // For convenience, we can directly use array sorting, performance is good enough for N=100.
            // Or strictly implement MinHeap.
            
            // Let's correct it to: Maintain Top N Largest Items -> Need Min Heap to evict the smallest.
            // But for simplicity and correctness, for N=100, directly append then sort dropLast is also fine, or insertion sort.
            // To follow the spirit of the ROADMAP, I use a simple and efficient way: insert and keep sorted.
            
            heap.append(element)
            heap.sort() // Ascending, last is the largest
            if heap.count > capacity {
                heap.removeFirst() // Remove the smallest
            }
        } else {
            // heap is full.
            // heap.first is the smallest of the top N.
            if let min = heap.first, element > min {
                heap[0] = element
                heap.sort() // Re-sort
            }
        }
    }

    var elements: [Element] { heap.sorted(by: >) } // Return descending
}
