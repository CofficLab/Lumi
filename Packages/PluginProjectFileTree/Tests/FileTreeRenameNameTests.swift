import Testing

@testable import PluginProjectFileTree

/// 回归 #1108：重命名弹窗曾无条件裁剪首尾空格，导致未修改预填名称直接确认时
/// 也会把合法文件名（如 ` draft `）静默改成 `draft`。
@MainActor
struct FileTreeRenameNameTests {

    @Test("直接确认预填名称不会触发重命名")
    func unchangedRenameIsNoOp() {
        #expect(FileTreeActions.renameTarget(from: " draft ", currentName: " draft ") == nil)
    }

    @Test("重命名保留合法首尾空格")
    func renameKeepsLeadingAndTrailingSpaces() {
        #expect(FileTreeActions.renameTarget(from: "  draft  ", currentName: "draft") == "  draft  ")
    }

    @Test("清空输入不会触发重命名")
    func emptyRenameIsNoOp() {
        #expect(FileTreeActions.renameTarget(from: "", currentName: "draft") == nil)
    }

    @Test("新建文件仍裁剪首尾空格")
    func creationNameTrimsSpaces() {
        #expect(FileTreeActions.creationName(from: "  note.txt  ") == "note.txt")
    }

    @Test("纯空格的新建名称被拒绝")
    func whitespaceOnlyCreationNameIsRejected() {
        #expect(FileTreeActions.creationName(from: "   ") == nil)
    }
}
