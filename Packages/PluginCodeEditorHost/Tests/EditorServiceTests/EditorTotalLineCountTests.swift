import EditorKernel
import Foundation
import Testing
@testable import EditorService

/// 编辑器总行数的增量维护（见 issue #1329）。
///
/// 原生输入路径（每次按键）过去会全量扫描正文统计换行数，
/// 修复后改为从行偏移表缓存读取（O(1)）。
@MainActor
struct EditorTotalLineCountTests {

    /// 构造一个带初始正文的 `EditorState`。
    private func makeState(text: String) -> EditorState {
        let state = EditorState(editorExtensions: EditorExtensionRegistry())
        _ = state.documentController.load(text: text)
        state.content = state.documentController.textStorage
        state.applyTotalLineCountAfterReplacement(of: text)
        return state
    }

    @Test("整体替换后总行数正确")
    func totalLineCountAfterReplacement() {
        let state = makeState(text: "a\nb\nc")
        #expect(state.totalLines == 3)
    }

    @Test("原生输入后总行数按编辑增量更新")
    func totalLineCountAfterNativeEdit() {
        let state = makeState(text: "a\nb\nc")
        #expect(state.totalLines == 3)

        // 在第一行末尾插入一个换行：总行数 +1。
        state.applyNativeTextEdit(range: NSRange(location: 1, length: 0), text: "\n")
        #expect(state.totalLines == 4)

        // 删掉刚插入的换行：总行数 -1。
        state.applyNativeTextEdit(range: NSRange(location: 1, length: 1), text: "")
        #expect(state.totalLines == 3)
    }

    @Test("原生输入替换多行区间时总行数正确")
    func totalLineCountAfterMultiLineNativeEdit() {
        let state = makeState(text: "a\nb\nc\nd")
        #expect(state.totalLines == 4)

        // 把 "b\nc" 整段替换为 "x"：少了一个换行。
        state.applyNativeTextEdit(range: NSRange(location: 2, length: 3), text: "x")
        #expect(state.totalLines == 3)
    }

    @Test("总行数与正文换行数始终一致")
    func totalLineCountAlwaysMatchesDocument() {
        let state = makeState(text: "first\nsecond")

        let edits: [(NSRange, String)] = [
            (NSRange(location: 5, length: 0), "\n"),
            (NSRange(location: 0, length: 5), "x\ny\n"),
            (NSRange(location: 0, length: 0), "z"),
            (NSRange(location: 0, length: 1), "")
        ]

        for (range, text) in edits {
            state.applyNativeTextEdit(range: range, text: text)
            let expected = (state.documentController.currentText ?? "").filter { $0 == "\n" }.count + 1
            #expect(state.totalLines == expected)
        }
    }
}
