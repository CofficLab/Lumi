import Foundation
import SwiftUI

// MARK: - Git Diff

public struct GitDiff: Codable {
    public let content: String
    public let stats: GitDiffStats?

    public init(content: String, stats: GitDiffStats?) {
        self.content = content
        self.stats = stats
    }

    public var isEmpty: Bool {
        content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

public struct GitDiffStats: Codable {
    public let filesChanged: Int
    public let insertions: Int
    public let deletions: Int

    public init(filesChanged: Int, insertions: Int, deletions: Int) {
        self.filesChanged = filesChanged
        self.insertions = insertions
        self.deletions = deletions
    }
}

// MARK: - Git Change Type

/// 文件变更类型
public enum GitChangeType: String, Codable, Sendable {
    case modified = "M"
    case added = "A"
    case deleted = "D"
    case renamed = "R"
    case untracked = "?"

    /// 显示用的短标签
    public var displayLabel: String {
        switch self {
        case .modified: return "M"
        case .added: return "A"
        case .deleted: return "D"
        case .renamed: return "R"
        case .untracked: return "?"
        }
    }

    /// 对应的颜色
    public var color: Color {
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
public struct GitChangedFile: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public let path: String
    public let changeType: GitChangeType

    public static func == (lhs: GitChangedFile, rhs: GitChangedFile) -> Bool {
        lhs.path == rhs.path
    }
}
