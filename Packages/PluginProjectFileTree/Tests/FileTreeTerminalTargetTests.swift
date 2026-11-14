import Foundation
import Testing
@testable import PluginProjectFileTree

/// 文件树「在终端中打开」的路径换算（见 issue #1296）。
///
/// AppleScript 的执行本身是同步 Apple Event，代码已把它挪到后台线程；
/// 这里锁定「终端要切到哪个目录」的语义。
@Suite("FileTreeFacade 终端路径")
struct FileTreeTerminalTargetTests {

    @Test("目录取自身")
    func directoryUsesItself() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("terminal-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        #expect(FileTreeFacade.terminalTargetPath(for: root) == root.path)
    }

    @Test("文件取其所在目录")
    func fileUsesItsDirectory() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("terminal-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let file = root.appendingPathComponent("a.txt")
        try Data("x".utf8).write(to: file)

        #expect(FileTreeFacade.terminalTargetPath(for: file) == root.path)
    }

    @Test("不存在的路径按文件处理")
    func missingPathUsesParentDirectory() {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-\(UUID().uuidString).txt")

        #expect(
            FileTreeFacade.terminalTargetPath(for: missing)
            == FileManager.default.temporaryDirectory.path
        )
    }
}
