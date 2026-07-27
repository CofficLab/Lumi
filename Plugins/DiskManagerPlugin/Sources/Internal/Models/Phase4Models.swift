import Foundation
import LumiKernel

// MARK: - Project Cleanup Models

public struct ProjectInfo: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public let name: String
    public let path: String
    public let type: ProjectType
    public let cleanableItems: [CleanableItem]

    public var totalSize: Int64 {
        cleanableItems.reduce(0) { $0 + $1.size }
    }

    public init(name: String, path: String, type: ProjectType, cleanableItems: [CleanableItem]) {
        self.name = name
        self.path = path
        self.type = type
        self.cleanableItems = cleanableItems
    }

    public enum ProjectType: String, CaseIterable, Sendable {
        case node = "Node.js"
        case rust = "Rust"
        case swift = "Swift/Xcode"
        case python = "Python"
        case generic = "Generic"

        public var displayName: String {
            switch self {
            case .node: return LumiPluginLocalization.string("Node.js", bundle: .module)
            case .rust: return LumiPluginLocalization.string("Rust", bundle: .module)
            case .swift: return LumiPluginLocalization.string("Swift/Xcode", bundle: .module)
            case .python: return LumiPluginLocalization.string("Python", bundle: .module)
            case .generic: return LumiPluginLocalization.string("Generic", bundle: .module)
            }
        }

        public var icon: String {
            switch self {
            case .node: return "hexagon"
            case .rust: return "gearshape"
            case .swift: return "swift"
            case .python: return "ladybug"
            case .generic: return "folder"
            }
        }
    }
}

public struct CleanableItem: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public let path: String
    public let name: String
    public let size: Int64

    public init(path: String, name: String, size: Int64) {
        self.path = path
        self.name = name
        self.size = size
    }
}
