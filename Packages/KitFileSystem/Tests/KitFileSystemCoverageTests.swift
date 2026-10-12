import Foundation
import Testing
@testable import KitFileSystem

@Suite("WorkspaceFileEditor 错误路径补充")
struct WorkspaceFileEditorCoverageTests {

    private func makeTemp() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("KitFSCov-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("编辑已有文件但 oldString 未命中 → 抛错且内容不变")
    func editNotFoundInExistingFile() throws {
        let dir = try makeTemp()
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = dir.appendingPathComponent("f.txt").path
        try "alpha beta".write(toFile: path, atomically: true, encoding: .utf8)

        #expect(throws: (any Error).self) {
            try WorkspaceFileEditor().edit(filePath: path, oldString: "gamma", newString: "delta")
        }
        // 内容未被改动
        #expect(try String(contentsOfFile: path, encoding: .utf8) == "alpha beta")
    }

    @Test("oldString 与 newString 完全相同 → 抛错")
    func editNoopThrows() throws {
        let dir = try makeTemp()
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = dir.appendingPathComponent("f.txt").path
        try "same".write(toFile: path, atomically: true, encoding: .utf8)

        do {
            _ = try WorkspaceFileEditor().edit(filePath: path, oldString: "same", newString: "same")
            Issue.record("期望抛错")
        } catch {
            #expect(error.localizedDescription.contains("No changes"))
        }
    }

    @Test("编辑已有非空文件但 oldString 为空 → 抛错")
    func editEmptyOldStringOnNonEmptyFile() throws {
        let dir = try makeTemp()
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = dir.appendingPathComponent("f.txt").path
        try "content".write(toFile: path, atomically: true, encoding: .utf8)

        #expect(throws: (any Error).self) {
            try WorkspaceFileEditor().edit(filePath: path, oldString: "", newString: "x")
        }
    }
}

@Suite("WorkspaceFileReader 截断边界补充")
struct WorkspaceFileReaderTruncationTests {

    private func makeTemp() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("KitFSReadCov-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("内容长度恰好等于上限时不截断")
    func boundaryAtExactLimit() throws {
        let dir = try makeTemp()
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = dir.appendingPathComponent("f.txt").path
        try "abc".write(toFile: path, atomically: true, encoding: .utf8)

        let result = try WorkspaceFileReader(textCharacterLimit: 3).read(path: path)
        if case .text(let content, _, let truncated) = result {
            #expect(content == "abc")
            #expect(truncated == false)
        } else {
            Issue.record("期望 text 结果")
        }
    }
}

@Suite("WorkspaceReadFileState 乐观并发状态")
struct WorkspaceReadFileStateTests {

    @Test("recordRead / snapshot / clear 按会话隔离")
    func recordSnapshotClear() {
        let state = WorkspaceReadFileState()
        let conv = UUID()
        let otherConv = UUID()
        let path = "/tmp/some/file.swift"
        let snap = WorkspaceReadFileSnapshot(modificationDate: Date())

        state.recordRead(conversationID: conv, path: path, snapshot: snap)

        #expect(state.snapshot(for: conv, path: path)?.modificationDate == snap.modificationDate)
        // 其他会话看不到
        #expect(state.snapshot(for: otherConv, path: path) == nil)

        state.clear(conversationID: conv)
        #expect(state.snapshot(for: conv, path: path) == nil)
    }
}

@Suite("FileTreeService 图标映射补充")
struct FileTreeServiceIconTests {

    @Test("更多扩展名映射为已知图标")
    func moreIcons() {
        #expect(FileTreeService.iconSFSymbol(forFileExtension: "jpg") != "doc")
        #expect(FileTreeService.iconSFSymbol(forFileExtension: "pdf") == "doc.richtext")
        // 不区分大小写
        #expect(FileTreeService.iconSFSymbol(forFileExtension: "PDF") == "doc.richtext")
    }
}
