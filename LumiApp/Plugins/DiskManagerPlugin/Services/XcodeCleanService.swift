import Foundation
import OSLog
import MagicKit

@MainActor
class XcodeCleanService: SuperLog {
    nonisolated static let emoji = "🧼"
    nonisolated static let verbose = false

    static let shared = XcodeCleanService()
    private let fileManager = FileManager.default

    // For testing purposes
    var customRootDirectory: URL?

    private init() {
        if Self.verbose {
            os_log("\(self.t)Xcode cleaning service initialized")
        }
    }
    
    // MARK: - Paths
    
    private func getPath(for category: XcodeCleanCategory) -> URL? {
        let home = fileManager.homeDirectoryForCurrentUser
        let developer: URL
        
        if let customRoot = customRootDirectory {
            developer = customRoot.appendingPathComponent("Library/Developer")
        } else {
            developer = home.appendingPathComponent("Library/Developer")
        }
        
        switch category {
        case .derivedData:
            return developer.appendingPathComponent("Xcode/DerivedData")
        case .archives:
            return developer.appendingPathComponent("Xcode/Archives")
        case .iOSDeviceSupport:
            return developer.appendingPathComponent("Xcode/iOS DeviceSupport")
        case .watchOSDeviceSupport:
            return developer.appendingPathComponent("Xcode/watchOS DeviceSupport")
        case .tvOSDeviceSupport:
            return developer.appendingPathComponent("Xcode/tvOS DeviceSupport")
        case .simulatorCaches:
            return developer.appendingPathComponent("CoreSimulator/Caches")
        case .logs:
            if let customRoot = customRootDirectory {
                return customRoot.appendingPathComponent("Library/Logs/CoreSimulator")
            }
            return home.appendingPathComponent("Library/Logs/CoreSimulator")
        }
    }
    
    // MARK: - Scanning
    
    func scan(category: XcodeCleanCategory) async -> [XcodeCleanItem] {
        guard let url = getPath(for: category) else { return [] }

        if Self.verbose {
            os_log("\(self.t)Scanning \(category.rawValue): \(url.path)")
        }

        // If directory doesn't exist, return empty
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
            if Self.verbose {
                os_log("\(self.t)Directory does not exist: \(url.path)")
            }
            return []
        }

        do {
            let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles])

            var items: [XcodeCleanItem] = []

            for itemURL in contents {
                // For Archives, Xcode creates subfolders by date (YYYY-MM-DD). We need to recurse or use the date folder as a unit.
                // Usually Archives structure is Archives/YYYY-MM-DD/AppName.xcarchive
                // For simplicity, we list the date folders under Archives.
                // DevCleaner usually shows by date. Here we show by top-level subdirectories (date or project name).

                let size = calculateSize(of: itemURL)
                let attributes = try itemURL.resourceValues(forKeys: [.contentModificationDateKey])
                let date = attributes.contentModificationDate ?? Date()

                var version: String? = nil
                if category == .iOSDeviceSupport || category == .watchOSDeviceSupport || category == .tvOSDeviceSupport {
                    // Try to parse version from folder name, e.g., "15.2 (19C56)"
                    version = itemURL.lastPathComponent
                }

                let item = XcodeCleanItem(
                    name: itemURL.lastPathComponent,
                    path: itemURL,
                    size: size,
                    category: category,
                    modificationDate: date,
                    version: version
                )
                items.append(item)
            }

            return items
        } catch {
            os_log(.error, "\(self.t)Scan failed: \(category.rawValue) - \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Helpers
    
    private func calculateSize(of url: URL) -> Int64 {
        // Simple recursive size calculation
        // Note: This might be slow, production environment may need optimization or use URL resource keys
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .totalFileAllocatedSizeKey]) else {
            return 0
        }
        
        var totalSize: Int64 = 0
        
        for case let fileURL as URL in enumerator {
            do {
                let values = try fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileSizeKey])
                if let size = values.totalFileAllocatedSize ?? values.fileSize {
                    totalSize += Int64(size)
                }
            } catch {
                continue
            }
        }
        
        return totalSize
    }
    
    // MARK: - Cleaning

    func delete(items: [XcodeCleanItem]) async throws {
        if Self.verbose {
            os_log("\(self.t)Starting deletion of \(items.count) items")
        }

        for item in items {
            if Self.verbose {
                os_log("\(self.t)Deleting: \(item.name)")
            }
            try fileManager.removeItem(at: item.path)
        }

        if Self.verbose {
            os_log("\(self.t)Deletion complete")
        }
    }
}
