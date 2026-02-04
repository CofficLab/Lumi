import Foundation
import AppKit

// MARK: - 缓存清理模型

struct CacheCategory: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let icon: String
    var paths: [CachePath]
    let safetyLevel: SafetyLevel

    var totalSize: Int64 {
        paths.reduce(0) { $0 + $1.size }
    }
    
    var fileCount: Int {
        paths.reduce(0) { $0 + $1.fileCount }
    }

    enum SafetyLevel: Int, Comparable {
        case safe = 0      // 可安全删除
        case medium = 1    // 需要用户确认
        case risky = 2     // 可能影响系统
        
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
            case .safe: return "安全"
            case .medium: return "谨慎"
            case .risky: return "风险"
            }
        }
    }
}

struct CachePath: Identifiable, Hashable {
    let id = UUID()
    let path: String
    let name: String
    let description: String
    let size: Int64
    let fileCount: Int
    let canDelete: Bool
    let icon: NSImage?
    
    // 用于 UI 选中状态
    var isSelected: Bool = true
    
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
