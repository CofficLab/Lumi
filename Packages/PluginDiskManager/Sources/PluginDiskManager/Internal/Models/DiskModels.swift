import AppKit
import Foundation

// MARK: - Disk Usage

public struct DiskUsage: Codable, Sendable {
    public let total: Int64
    public let used: Int64
    public let available: Int64

    public var usedPercentage: Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total)
    }

    public init(total: Int64, used: Int64, available: Int64) {
        self.total = `total`
        self.used = used
        self.available = available
    }
}

// MARK: - Directory Scan Model

public struct DirectoryEntry: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let name: String
    public let path: String
    public let size: Int64
    public let isDirectory: Bool
    public let lastAccessed: Date
    public let modificationDate: Date
    public var children: [DirectoryEntry]?  // nil means not scanned or not a directory

    public var isScanned: Bool { children != nil }
    public var depth: Int { path.components(separatedBy: "/").count }

    public static func == (lhs: DirectoryEntry, rhs: DirectoryEntry) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public init(id: String, name: String, path: String, size: Int64, isDirectory: Bool, lastAccessed: Date, modificationDate: Date, children: [DirectoryEntry]?) {
        self.id = id
        self.name = name
        self.path = path
        self.size = size
        self.isDirectory = isDirectory
        self.lastAccessed = lastAccessed
        self.modificationDate = modificationDate
        self.children = children
    }
}

// MARK: - Large File Model

public struct LargeFileEntry: Identifiable, Hashable, Codable, Comparable, Sendable {
    public let id: String
    public let name: String
    public let path: String
    public let size: Int64
    public let modificationDate: Date
    public let fileType: FileType

    public static func < (lhs: LargeFileEntry, rhs: LargeFileEntry) -> Bool {
        return lhs.size < rhs.size
    }

    public init(id: String, name: String, path: String, size: Int64, modificationDate: Date, fileType: FileType) {
        self.id = id
        self.name = name
        self.path = path
        self.size = size
        self.modificationDate = modificationDate
        self.fileType = fileType
    }

    public enum FileType: String, Codable, Sendable {
        case document, image, video, audio, archive, code, other

        public static func from(extension ext: String) -> FileType {
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
}

// MARK: - Scan Result

public struct ScanResult: Sendable {
    public let entries: [DirectoryEntry]
    public let largeFiles: [LargeFileEntry]
    public let totalSize: Int64
    public let totalFiles: Int
    public let scanDuration: TimeInterval
    public let scannedAt: Date

    public init(entries: [DirectoryEntry], largeFiles: [LargeFileEntry], totalSize: Int64, totalFiles: Int, scanDuration: TimeInterval, scannedAt: Date) {
        self.entries = entries
        self.largeFiles = largeFiles
        self.totalSize = totalSize
        self.totalFiles = totalFiles
        self.scanDuration = scanDuration
        self.scannedAt = scannedAt
    }
}

// MARK: - Scan Progress

public struct ScanProgress: Sendable {
    public let path: String
    public let currentPath: String
    public let scannedFiles: Int
    public let scannedDirectories: Int
    public let scannedBytes: Int64
    public let startTime: Date

    public init(path: String, currentPath: String, scannedFiles: Int, scannedDirectories: Int, scannedBytes: Int64, startTime: Date) {
        self.path = path
        self.currentPath = currentPath
        self.scannedFiles = scannedFiles
        self.scannedDirectories = scannedDirectories
        self.scannedBytes = scannedBytes
        self.startTime = startTime
    }

    public var duration: TimeInterval {
        Date().timeIntervalSince(startTime)
    }

    public var filesPerSecond: Double {
        duration > 0 ? Double(scannedFiles) / duration : 0
    }
}

// MARK: - Max Heap (for Top N large files)

public struct MaxHeap<Element: Hashable & Comparable & Sendable>: Sendable {
    private var heap: [Element] = []
    private let capacity: Int

    public init(capacity: Int) {
        self.capacity = capacity
    }

    public mutating func insert(_ element: Element) {
        if heap.count < capacity {
            heap.append(element)
            heap.sort()
            if heap.count > capacity {
                heap.removeFirst()
            }
        } else {
            if let min = heap.first, element > min {
                heap[0] = element
                heap.sort()
            }
        }
    }

    public var elements: [Element] { heap.sorted(by: >) }
}
