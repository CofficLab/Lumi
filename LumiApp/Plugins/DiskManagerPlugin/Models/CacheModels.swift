import Foundation
import AppKit

// MARK: - Cache Cleanup Models

struct CacheCategory: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let icon: String
    var paths: [CachePath] {
        didSet {
            recalculateTotals()
        }
    }
    let safetyLevel: SafetyLevel
    
    private(set) var totalSize: Int64 = 0
    private(set) var fileCount: Int = 0
    
    init(id: String, name: String, description: String, icon: String, paths: [CachePath], safetyLevel: SafetyLevel) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.paths = paths
        self.safetyLevel = safetyLevel
        recalculateTotals()
    }
    
    private mutating func recalculateTotals() {
        totalSize = paths.reduce(0) { $0 + $1.size }
        fileCount = paths.reduce(0) { $0 + $1.fileCount }
    }

    enum SafetyLevel: Int, Comparable {
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

struct CachePath: Identifiable, Hashable {
    let id = UUID()
    let path: String
    let name: String
    let description: String
    let size: Int64
    let fileCount: Int
    let canDelete: Bool
    let icon: NSImage?
    
    // Used for UI selection state
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
