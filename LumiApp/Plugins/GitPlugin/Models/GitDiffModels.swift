import Foundation
import SwiftUI

// MARK: - Git Diff

struct GitDiff: Codable {
    let content: String
    let stats: GitDiffStats?

    var isEmpty: Bool {
        content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct GitDiffStats: Codable {
    let filesChanged: Int
    let insertions: Int
    let deletions: Int
}

// MARK: - Git Change Type

/// 文件变更类型
enum GitChangeType: String, Codable {
    case modified = "M"
    case added = "A"
    case deleted = "D"
    case renamed = "R"
    case untracked = "?"

    /// 显示用的短标签
    var displayLabel: String {
        switch self {
        case .modified: return "M"
        case .added: return "A"
        case .deleted: return "D"
        case .renamed: return "R"
        case .untracked: return "?"
        }
    }

    /// 对应的颜色
    var color: Color {
        switch self {
        case .modified: return .orange
        case .added: return .green
        case .deleted: return .red
        case .renamed: return .blue
        case .untracked: return .gray
        }
    }
}

/// 变更文件模型
struct GitChangedFile: Identifiable, Equatable {
    let id = UUID()
    let path: String
    let changeType: GitChangeType

    static func == (lhs: GitChangedFile, rhs: GitChangedFile) -> Bool {
        lhs.path == rhs.path
    }
}
