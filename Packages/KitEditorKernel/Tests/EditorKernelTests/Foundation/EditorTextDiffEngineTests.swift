import Testing
@testable import EditorKernel

/// `EditorTextDiffEngine` 契约测试（§21.1：diff 确定性）。
@Suite("Editor Text Diff Engine")
struct EditorTextDiffEngineTests {
    @Test("相同文本产生空 diff")
    func identicalTextsProduceEmptyDiff() {
        let text = "a\nb\nc\n"
        let result = EditorTextDiffEngine.diff(oldText: text, newText: text)
        #expect(result.isEmpty)
        #expect(result.addedLineCount == 0)
        #expect(result.removedLineCount == 0)
    }

    @Test("空文本到内容为纯新增")
    func emptyToContentIsPureAddition() {
        let result = EditorTextDiffEngine.diff(oldText: "", newText: "a\nb\n")
        #expect(result.hunks.count == 1)
        #expect(result.addedLineCount == 2)
        #expect(result.removedLineCount == 0)
        #expect(result.hunks[0].addedContents == ["a", "b"])
        #expect(result.hunks[0].oldChangeRange == nil)
        #expect(result.hunks[0].newChangeRange == 1...2)
    }

    @Test("内容到空文本为纯删除")
    func contentToEmptyIsPureRemoval() {
        let result = EditorTextDiffEngine.diff(oldText: "a\nb\n", newText: "")
        #expect(result.hunks.count == 1)
        #expect(result.removedLineCount == 2)
        #expect(result.addedLineCount == 0)
        #expect(result.hunks[0].removedContents == ["a", "b"])
        #expect(result.hunks[0].newChangeRange == nil)
    }

    @Test("单行修改产生 removed + added 对")
    func singleLineModification() {
        let old = "alpha\nbeta\ngamma"
        let new = "alpha\nBETA\ngamma"
        let result = EditorTextDiffEngine.diff(oldText: old, newText: new)

        #expect(result.hunks.count == 1)
        #expect(result.hunks[0].removedContents == ["beta"])
        #expect(result.hunks[0].addedContents == ["BETA"])
        // 上下文行（alpha/gamma）保留。
        #expect(result.hunks[0].lines.map(\.content) == ["alpha", "beta", "BETA", "gamma"])
        #expect(result.hunks[0].oldChangeRange == 2...2)
        #expect(result.hunks[0].newChangeRange == 2...2)
    }

    @Test("相距较远的变更切分为多个 hunk")
    func distantChangesSplitIntoHunks() {
        let old = (1...20).map { "line\($0)" }.joined(separator: "\n")
        let new = (1...20).map { $0 == 3 || $0 == 18 ? "CHANGED\($0)" : "line\($0)" }
            .joined(separator: "\n")

        let result = EditorTextDiffEngine.diff(oldText: old, newText: new)
        #expect(result.hunks.count == 2)
        #expect(result.hunks[0].newChangeRange!.contains(3))
        #expect(result.hunks[1].newChangeRange!.contains(18))
    }

    @Test("相距较近的变更合并为一个 hunk")
    func nearbyChangesMergeIntoOneHunk() {
        let old = (1...12).map { "line\($0)" }.joined(separator: "\n")
        let new = (1...12).map { $0 == 4 || $0 == 5 ? "CHANGED\($0)" : "line\($0)" }
            .joined(separator: "\n")

        let result = EditorTextDiffEngine.diff(oldText: old, newText: new)
        #expect(result.hunks.count == 1)
        #expect(result.addedLineCount == 2)
        #expect(result.removedLineCount == 2)
    }

    @Test("行号映射：旧行号与新行号各自连续正确")
    func lineNumbersMapCorrectly() {
        let old = "a\nb\nc\nd\ne"
        let new = "a\nX\nc\nd\nY"
        let result = EditorTextDiffEngine.diff(oldText: old, newText: new)

        let allLines = result.hunks.flatMap(\.lines)
        let oldNumbers = allLines.compactMap(\.oldLineNumber)
        let newNumbers = allLines.compactMap(\.newLineNumber)
        // 旧行号严格递增且不重复。
        #expect(oldNumbers == oldNumbers.sorted())
        #expect(Set(oldNumbers).count == oldNumbers.count)
        #expect(newNumbers == newNumbers.sorted())
        #expect(Set(newNumbers).count == newNumbers.count)
        // unchanged 行旧行号 == 新行号（首尾未变区）。
        for line in allLines where line.kind == .unchanged {
            #expect(line.oldLineNumber == line.newLineNumber)
        }
    }

    @Test("CRLF 与 LF 混合输入可比较（行尾 CR 归一化）")
    func crlfInputsNormalize() {
        let result = EditorTextDiffEngine.diff(oldText: "a\r\nb\r\n", newText: "a\nb\n")
        #expect(result.isEmpty)
    }

    @Test("同输入必得同输出（确定性）")
    func deterministicOutput() {
        let old = Array(1...50).map { "old\($0)" }.joined(separator: "\n")
        let new = Array(1...50).map { $0 % 7 == 0 ? "new\($0)" : "old\($0)" }.joined(separator: "\n")
        let first = EditorTextDiffEngine.diff(oldText: old, newText: new)
        let second = EditorTextDiffEngine.diff(oldText: old, newText: new)
        #expect(first == second)
    }

    @Test("尾随换行差异不产生空行 diff")
    func trailingNewlineHandling() {
        let result = EditorTextDiffEngine.diff(oldText: "a\nb\n", newText: "a\nb")
        #expect(result.isEmpty)
    }
}
