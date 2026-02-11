import Foundation
import AppKit

// MARK: - Cache Cleanup Models

struct CacheCategory: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let paths: [CachePath]
    let safetyLevel: SafetyLevel
    let totalSize: Int64
    let fileCount: Int

    init(id: String, name: String, description: String, icon: String, paths: [CachePath], safetyLevel: SafetyLevel) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.paths = paths
        self.safetyLevel = safetyLevel
        // 计算总计值（避免使用 didSet，改为在 init 中直接计算）
        self.totalSize = paths.reduce(0) { $0 + $1.size }
        self.fileCount = paths.reduce(0) { $0 + $1.fileCount }
    }

    enum SafetyLevel: Int, Comparable, Sendable {
        case safe = 0      // Safe to delete
        case medium = 1    // Requires user confirmation
        case risky = 2     // May affect system

        static func < (lhs: SafetyLevel, rhs: SafetyLevel) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        var color: String {
            switch self {
            case .safe: return "green"
            case .medium: return "orange"
            case .risky: return "red"
            }
        }

        var label: String {
            switch self {
            case .safe: return "Safe"
            case .medium: return "Medium"
            case .risky: return "Risky"
            }
        }
    }
}

/// 可跨 Actor 边界传递的缓存路径模型（Sendable）
struct CachePath: Identifiable, Hashable, Sendable {
    let id: UUID
    let path: String
    let name: String
    let description: String
    let size: Int64
    let fileCount: Int
    let canDelete: Bool

    init(path: String, name: String, description: String, size: Int64, fileCount: Int, canDelete: Bool) {
        self.id = UUID()
        self.path = path
        self.name = name
        self.description = description
        self.size = size
        self.fileCount = fileCount
        self.canDelete = canDelete
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: CachePath, rhs: CachePath) -> Bool {
        lhs.id == rhs.id
    }
}

struct CleanupResult {
    let categories: [CacheCategory]
    let totalSize: Int64
    let totalFiles: Int
    let cleanedAt: Date
}
