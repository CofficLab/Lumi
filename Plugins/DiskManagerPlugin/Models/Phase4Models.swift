import Foundation
import AppKit

// MARK: - 应用卸载模型

struct ApplicationInfo: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let path: String
    let bundleId: String?
    let icon: NSImage?
    let size: Int64
    let lastAccessed: Date?
    
    // 用于 Hashable 和 Equatable
    static func == (lhs: ApplicationInfo, rhs: ApplicationInfo) -> Bool {
        lhs.path == rhs.path
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(path)
    }
}

struct RelatedFile: Identifiable, Hashable {
    let id = UUID()
    let path: String
    let size: Int64
    let type: RelatedFileType
    
    var name: String {
        (path as NSString).lastPathComponent
    }
    
    enum RelatedFileType: String, Codable {
        case app
        case support
        case cache
        case preferences
        case state
        case container
        case log
        case other
        
        var displayName: String {
            switch self {
            case .app: return "Application"
            case .support: return "Application Support"
            case .cache: return "Caches"
            case .preferences: return "Preferences"
            case .state: return "Saved State"
            case .container: return "Containers"
            case .log: return "Logs"
            case .other: return "Other"
            }
        }
    }
}

// MARK: - 项目清理模型

struct ProjectInfo: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let path: String
    let type: ProjectType
    let cleanableItems: [CleanableItem]
    
    var totalSize: Int64 {
        cleanableItems.reduce(0) { $0 + $1.size }
    }
    
    enum ProjectType: String, CaseIterable {
        case node = "Node.js"
        case rust = "Rust"
        case swift = "Swift/Xcode"
        case python = "Python"
        case generic = "Generic"
        
        var icon: String {
            switch self {
            case .node: return "hexagon"
            case .rust: return "gearshape"
            case .swift: return "swift"
            case .python: return "ladybug" // SF Symbol placeholder
            case .generic: return "folder"
            }
        }
    }
}

struct CleanableItem: Identifiable, Hashable {
    let id = UUID()
    let path: String
    let name: String // e.g., "node_modules", "target"
    let size: Int64
}
