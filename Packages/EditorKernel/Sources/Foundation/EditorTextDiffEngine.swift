import Foundation

// MARK: - 文本 Diff 引擎（纯逻辑，Phase 7 §15.5）
//
// 行级 diff：先做等值行裁剪（prefix/suffix），再用 LCS（动态规划）
// 生成等值行序列，最后切分成带上下文的 hunk。
// 确定性：同输入必得同输出（§21.1 聚合确定性要求同源）。
// 该引擎同时服务 Diff 面板、Agent 修改预览与逐块接受/拒绝（§16）。

/// 单行 diff 条目。
public struct EditorDiffLine: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case unchanged
        case added
        case removed
    }

    public let kind: Kind

    /// 旧文本行号（1-based；added 行为 nil）。
    public let oldLineNumber: Int?

    /// 新文本行号（1-based；removed 行为 nil）。
    public let newLineNumber: Int?

    public let content: String

    public init(kind: Kind, oldLineNumber: Int?, newLineNumber: Int?, content: String) {
        self.kind = kind
        self.oldLineNumber = oldLineNumber
        self.newLineNumber = newLineNumber
        self.content = content
    }
}

/// 一个 diff hunk：一段连续变更及其上下文。
public struct EditorDiffHunk: Equatable, Sendable {
    /// hunk 首行在旧文本中的行号（1-based；纯新增时指向插入点之后的行）。
    public let oldStart: Int

    /// hunk 首行在新文本中的行号（1-based）。
    public let newStart: Int

    public let lines: [EditorDiffLine]

    public init(oldStart: Int, newStart: Int, lines: [EditorDiffLine]) {
        self.oldStart = oldStart
        self.newStart = newStart
        self.lines = lines
    }

    /// hunk 是否包含任何变更行。
    public var hasChanges: Bool {
        lines.contains { $0.kind != .unchanged }
    }

    /// 该 hunk 的所有新增行内容。
    public var addedContents: [String] {
        lines.filter { $0.kind == .added }.map(\.content)
    }

    /// 该 hunk 的所有删除行内容。
    public var removedContents: [String] {
        lines.filter { $0.kind == .removed }.map(\.content)
    }

    /// 该 hunk 中变更行（保留顺序）在**新文本**中的行范围（1-based 闭区间；纯删除为 nil）。
    public var newChangeRange: ClosedRange<Int>? {
        let numbers = lines.compactMap { $0.kind == .added ? $0.newLineNumber : nil }
        guard let first = numbers.min(), let last = numbers.max() else { return nil }
        return first...last
    }

    /// 该 hunk 中变更行在**旧文本**中的行范围（1-based 闭区间；纯新增为 nil）。
    public var oldChangeRange: ClosedRange<Int>? {
        let numbers = lines.compactMap { $0.kind == .removed ? $0.oldLineNumber : nil }
        guard let first = numbers.min(), let last = numbers.max() else { return nil }
        return first...last
    }
}

/// 两次文本的 diff 结果。
public struct EditorDiffResult: Equatable, Sendable {
    public let hunks: [EditorDiffHunk]

    public init(hunks: [EditorDiffHunk]) {
        self.hunks = hunks
    }

    public static let empty = EditorDiffResult(hunks: [])

    public var isEmpty: Bool { hunks.isEmpty }

    /// 全部新增/删除行数。
    public var addedLineCount: Int {
        hunks.reduce(0) { $0 + $1.lines.filter { $0.kind == .added }.count }
    }

    public var removedLineCount: Int {
        hunks.reduce(0) { $0 + $1.lines.filter { $0.kind == .removed }.count }
    }
}

/// 行级 diff 计算器。
public enum EditorTextDiffEngine {
    /// 计算行级 diff 并按上下文切分 hunk。
    ///
    /// - Parameters:
    ///   - oldText: 基线文本。
    ///   - newText: 目标文本。
    ///   -contextLines: 每个 hunk 携带的上下文行数（与 Git 默认一致取 3）。
    public static func diff(
        oldText: String,
        newText: String,
        contextLines: Int = 3
    ) -> EditorDiffResult {
        let oldLines = Self.lines(of: oldText)
        let newLines = Self.lines(of: newText)
        let matchedPairs = lcsPairs(old: oldLines, new: newLines)

        // 生成完整行序列（removed/added/unchanged）。
        var entries: [EditorDiffLine] = []
        var oldIndex = 0
        var newIndex = 0
        var pairIndex = 0

        while pairIndex < matchedPairs.count || oldIndex < oldLines.count || newIndex < newLines.count {
            if pairIndex < matchedPairs.count {
                let (matchOld, matchNew) = matchedPairs[pairIndex]
                // 变更段：先 removed 后 added（与 unified diff 顺序一致）。
                while oldIndex < matchOld {
                    entries.append(
                        EditorDiffLine(kind: .removed, oldLineNumber: oldIndex + 1, newLineNumber: nil, content: oldLines[oldIndex])
                    )
                    oldIndex += 1
                }
                while newIndex < matchNew {
                    entries.append(
                        EditorDiffLine(kind: .added, oldLineNumber: nil, newLineNumber: newIndex + 1, content: newLines[newIndex])
                    )
                    newIndex += 1
                }
                entries.append(
                    EditorDiffLine(kind: .unchanged, oldLineNumber: matchOld + 1, newLineNumber: matchNew + 1, content: oldLines[matchOld])
                )
                oldIndex = matchOld + 1
                newIndex = matchNew + 1
                pairIndex += 1
            } else if oldIndex < oldLines.count {
                entries.append(
                    EditorDiffLine(kind: .removed, oldLineNumber: oldIndex + 1, newLineNumber: nil, content: oldLines[oldIndex])
                )
                oldIndex += 1
            } else if newIndex < newLines.count {
                entries.append(
                    EditorDiffLine(kind: .added, oldLineNumber: nil, newLineNumber: newIndex + 1, content: newLines[newIndex])
                )
                newIndex += 1
            }
        }

        return EditorDiffResult(hunks: splitIntoHunks(entries, contextLines: contextLines))
    }

    // MARK: - 行切分

    /// 按换行切分（保留空行；CRLF 先归一化为 LF——`\r\n` 在 Swift 中是单个
    /// 字素簇，直接按 `\n` 切分不会命中）。
    static func lines(of text: String) -> [String] {
        guard !text.isEmpty else { return [] }
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        var result = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        // 尾随换行产生的末尾空行不视为内容行。
        if normalized.hasSuffix("\n") { result.removeLast() }
        return result
    }

    // MARK: - LCS

    /// 公共子序列的 (oldIndex, newIndex) 对（按序）。
    ///
    /// 输入先做首尾等值裁剪，将 DP 规到中间变更区，
    /// 大文件下避免 O(n*m) 全表。
    static func lcsPairs(old: [String], new: [String]) -> [(Int, Int)] {
        var start = 0
        while start < old.count && start < new.count && old[start] == new[start] {
            start += 1
        }
        var oldEnd = old.count
        var newEnd = new.count
        while oldEnd > start && newEnd > start && old[oldEnd - 1] == new[newEnd - 1] {
            oldEnd -= 1
            newEnd -= 1
        }

        var pairs: [(Int, Int)] = []
        for i in 0..<start {
            pairs.append((i, i))
        }

        let midOld = Array(old[start..<oldEnd])
        let midNew = Array(new[start..<newEnd])
        pairs.append(contentsOf: lcsPairsCore(old: midOld, new: midNew).map { pair in
            (pair.0 + start, pair.1 + start)
        })

        // 尾部等值区：两侧等长（裁剪时成对回退），按剩余索引一一配对。
        var tailOld = oldEnd
        var tailNew = newEnd
        while tailOld < old.count && tailNew < new.count {
            pairs.append((tailOld, tailNew))
            tailOld += 1
            tailNew += 1
        }
        return pairs
    }

    /// 中间区域 LCS（动态规划，等值行哈希缓存降低比较成本）。
    private static func lcsPairsCore(old: [String], new: [String]) -> [(Int, Int)] {
        let n = old.count
        let m = new.count
        guard n > 0 && m > 0 else { return [] }

        var table = [[Int]](repeating: [Int](repeating: 0, count: m + 1), count: n + 1)
        for i in stride(from: n - 1, through: 0, by: -1) {
            for j in stride(from: m - 1, through: 0, by: -1) {
                if old[i] == new[j] {
                    table[i][j] = table[i + 1][j + 1] + 1
                } else {
                    table[i][j] = max(table[i + 1][j], table[i][j + 1])
                }
            }
        }

        var pairs: [(Int, Int)] = []
        var i = 0
        var j = 0
        while i < n && j < m {
            if old[i] == new[j] {
                pairs.append((i, j))
                i += 1
                j += 1
            } else if table[i + 1][j] >= table[i][j + 1] {
                i += 1
            } else {
                j += 1
            }
        }
        return pairs
    }

    // MARK: - Hunk 切分

    /// 按变更段切分并附带上下文；相邻变更段间距 ≤ 2*context 时合并为一个 hunk。
    static func splitIntoHunks(_ entries: [EditorDiffLine], contextLines: Int) -> [EditorDiffHunk] {
        let changeIndices = entries.indices.filter { entries[$0].kind != .unchanged }
        guard !changeIndices.isEmpty else { return [] }

        var hunks: [EditorDiffHunk] = []
        var groupStart = changeIndices[0]
        var groupEnd = changeIndices[0]

        func appendHunk(range: ClosedRange<Int>) {
            let lower = max(range.lowerBound - contextLines, 0)
            let upper = min(range.upperBound + contextLines, entries.count - 1)
            let lines = Array(entries[lower...upper])

            // oldStart：窗口内首个旧行号；纯新增（无上下文旧行）时取插入点
            // （变更前最后一个旧行号 + 1，unified diff 惯例）。
            let oldStart = lines.compactMap(\.oldLineNumber).first
                ?? (entries[0..<range.lowerBound].compactMap(\.oldLineNumber).last ?? 0) + 1
            let newStart = lines.compactMap(\.newLineNumber).first
                ?? (entries[0..<range.lowerBound].compactMap(\.newLineNumber).last ?? 0) + 1
            hunks.append(EditorDiffHunk(oldStart: oldStart, newStart: newStart, lines: lines))
        }

        for index in changeIndices.dropFirst() {
            if index - groupEnd - 1 <= 2 * contextLines {
                groupEnd = index
            } else {
                appendHunk(range: groupStart...groupEnd)
                groupStart = index
                groupEnd = index
            }
        }
        appendHunk(range: groupStart...groupEnd)
        return hunks
    }
}
