import Foundation
import AppKit

// MARK: - Project Cleanup Models

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
        
        var displayName: String {
            switch self {
            case .node: return String(localized: "Node.js")
            case .rust: return String(localized: "Rust")
            case .swift: return String(localized: "Swift/Xcode")
            case .python: return String(localized: "Python")
            case .generic: return String(localized: "Generic")
            }
        }

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
