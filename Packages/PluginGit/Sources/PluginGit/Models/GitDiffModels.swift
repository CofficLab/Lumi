import Foundation
import SwiftUI

// MARK: - Git Diff

public struct GitDiff: Codable, Sendable {
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

public struct GitDiffStats: Codable, Sendable {
    public let filesChanged: Int
    public let insertions: Int
    public let deletions: Int

    public init(filesChanged: Int, insertions: Int, deletions: Int) {
        self.filesChanged = filesChanged
        self.insertions = insertions
        self.deletions = deletions
    }

    /// Count added/removed lines in unified diff content.
    ///
    /// Lines beginning with a single `+`/`-` are counted as insertions/deletions.
    /// Only real diff headers (`+++ <path>`, `--- <path>`) are skipped: they are
    /// the sole `+++`/`---` lines followed by whitespace, so source lines such as
    /// `++i;` (whose diff line is `+++i;`) still count.
    /// Context lines, hunk markers (`@@`), and metadata (`diff --git`, `index`)
    /// start with neither and are ignored.
    public static func countInsertionsDeletions(in content: String) -> (insertions: Int, deletions: Int) {
        var insertions = 0
        var deletions = 0
        for line in content.components(separatedBy: "\n") {
            guard !isFileHeader(line) else { continue }
            if line.hasPrefix("+") {
                insertions += 1
            } else if line.hasPrefix("-") {
                deletions += 1
            }
        }
        return (insertions, deletions)
    }

    /// `+++ b/file`、`--- a/file`（含 tab 分隔）才是文件头；
    /// `+++i;`、`---i;` 这类紧贴内容的行是真实增删行。
    private static func isFileHeader(_ line: String) -> Bool {
        for marker in ["+++", "---"] where line.hasPrefix(marker) {
            guard line.count > marker.count else { return true }
            let next = line[line.index(line.startIndex, offsetBy: marker.count)]
            return next == " " || next == "\t"
        }
        return false
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
