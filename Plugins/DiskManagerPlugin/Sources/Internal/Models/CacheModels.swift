import Foundation
import LumiKernel

// MARK: - Cache Cleanup Models

public struct CacheCategory: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let description: String
    public let icon: String
    public let paths: [CachePath]
    public let safetyLevel: SafetyLevel
    public let totalSize: Int64
    public let fileCount: Int

    public init(id: String, name: String, description: String, icon: String, paths: [CachePath], safetyLevel: SafetyLevel) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.paths = paths
        self.safetyLevel = safetyLevel
        self.totalSize = paths.reduce(0) { $0 + $1.size }
        self.fileCount = paths.reduce(0) { $0 + $1.fileCount }
    }

    public enum SafetyLevel: Int, Comparable, Sendable {
        case safe = 0      // Safe to delete
        case medium = 1    // Requires user confirmation
        case risky = 2     // May affect system

        public static func < (lhs: SafetyLevel, rhs: SafetyLevel) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        public var color: String {
            switch self {
            case .safe: return "green"
            case .medium: return "orange"
            case .risky: return "red"
            }
        }

        public var label: String {
            switch self {
            case .safe: return LumiPluginLocalization.string("Safe", bundle: .module)
            case .medium: return LumiPluginLocalization.string("Medium", bundle: .module)
            case .risky: return LumiPluginLocalization.string("Risky", bundle: .module)
            }
        }
    }
}

/// 缓存路径模型（Sendable）
public struct CachePath: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let path: String
    public let name: String
    public let description: String
    public let size: Int64
    public let fileCount: Int
    public let canDelete: Bool

    public init(id: UUID = UUID(), path: String, name: String, description: String, size: Int64, fileCount: Int, canDelete: Bool) {
        self.id = id
        self.path = path
        self.name = name
        self.description = description
        self.size = size
        self.fileCount = fileCount
        self.canDelete = canDelete
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: CachePath, rhs: CachePath) -> Bool {
        lhs.id == rhs.id
    }
}

public struct CleanupResult {
    public let categories: [CacheCategory]
    public let totalSize: Int64
    public let totalFiles: Int
    public let cleanedAt: Date

    public init(categories: [CacheCategory], totalSize: Int64, totalFiles: Int, cleanedAt: Date) {
        self.categories = categories
        self.totalSize = totalSize
        self.totalFiles = totalFiles
        self.cleanedAt = cleanedAt
    }
}
