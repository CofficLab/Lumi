import Foundation
import Testing
@testable import EditorKernel

struct LineOffsetIncrementalBugTests {
    @Test func replaceRemovingNewlineWithLongerText() {
        let t = LineOffsetTable(content: "x\ny\nc")
        // 用 "abcde" 替换 "x\ny"（range 0..3，净长度 +2，删除了一个换行）
        let t2 = t.update(editRange: NSRange(location: 0, length: 3), changeInLength: 2, newContent: "abcde")
        // "abcde\nc" → 第 0 行是 "abcde"，第 1 行 "c"
        #expect(t2.lineContaining(utf16Offset: 6) == 1) // 'c' 所在行
        #expect(t2.lineCount == 2)
    }
}

extension LineOffsetIncrementalBugTests {
    @Test func equalLengthReplaceRemovingNewline() {
        let t = LineOffsetTable(content: "x\ny\nc")
        let t2 = t.update(editRange: NSRange(location: 0, length: 3), changeInLength: 0, newContent: "abc")
        // "abc\nc" → 2 行
        #expect(t2.lineCount == 2)
        #expect(t2.lineContaining(utf16Offset: 4) == 1)
    }

    @Test func multiLineReplaceInsertingNewlines() {
        let t = LineOffsetTable(content: "ab\ncd\nef")
        // "b\nc"(1..4) 替换为 "XY\nZ"（5 字符，delta +1）
        let t2 = t.update(editRange: NSRange(location: 1, length: 3), changeInLength: 1, newContent: "XY\nZ")
        // "aXY\nZd\nef" → 3 行，起点 [0,4,7]
        #expect(t2.lineCount == 3)
        #expect(t2.utf16Offset(line: 1, character: 0) == 4)
        #expect(t2.utf16Offset(line: 2, character: 0) == 7)
    }
}
