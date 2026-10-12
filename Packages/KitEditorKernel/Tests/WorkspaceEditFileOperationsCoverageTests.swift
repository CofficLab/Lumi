import Testing
import Foundation
import LanguageServerProtocol
@testable import EditorKernel

@Suite("WorkspaceEditFileOperations coverage")
struct WorkspaceEditFileOperationsCoverageTests {
    private func makeRoot() -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("editor-kernel-cov-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    @Test("fileURL rejects non-file input")
    func fileURLRejects() {
        #expect(WorkspaceEditFileOperations.fileURL(from: "https://example.com/a.swift") == nil)
        #expect(WorkspaceEditFileOperations.fileURL(from: "  ") == nil)
        #expect(WorkspaceEditFileOperations.fileURL(from: "relative/path.swift") == nil)
    }

    @Test("create honors overwrite and ignoreIfExists")
    func createBranches() {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("file.swift").absoluteString
        FileManager.default.createFile(atPath: URL(string: file)!.path, contents: nil)

        // 已存在且无 overwrite：失败
        #expect(!WorkspaceEditFileOperations.applyCreateFile(uri: file, overwrite: false, ignoreIfExists: false))
        // 已存在且 ignoreIfExists：成功（幂等）
        #expect(WorkspaceEditFileOperations.applyCreateFile(uri: file, overwrite: false, ignoreIfExists: true))
        // 已存在且 overwrite：重建成功
        #expect(WorkspaceEditFileOperations.applyCreateFile(uri: file, overwrite: true, ignoreIfExists: false))
        // 非法 URI：失败
        #expect(!WorkspaceEditFileOperations.applyCreateFile(uri: "not-a-uri", overwrite: false, ignoreIfExists: false))
    }

    @Test("rename moves files and honors options")
    func renameBranches() throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let a = root.appendingPathComponent("a.swift")
        let b = root.appendingPathComponent("b.swift")
        FileManager.default.createFile(atPath: a.path, contents: Data("x".utf8))

        let options = try JSONDecoder().decode(
            RenameFileOptions.self,
            from: Data(#"{"overwrite": false, "ignoreIfExists": false}"#.utf8)
        )
        let op = RenameFile(
            kind: "rename",
            oldUri: a.absoluteString,
            newUri: b.absoluteString,
            options: options
        )
        #expect(WorkspaceEditFileOperations.applyRenameFile(op))
        #expect(FileManager.default.fileExists(atPath: b.path))
        #expect(!FileManager.default.fileExists(atPath: a.path))
    }

    @Test("rename via URI parameters handles missing and existing targets")
    func renameURIParameters() {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let a = root.appendingPathComponent("a.swift")
        let b = root.appendingPathComponent("b.swift")

        // 旧文件不存在
        #expect(WorkspaceEditFileOperations.applyRenameFile(
            oldURI: a.absoluteString, newURI: b.absoluteString, overwrite: false, ignoreIfExists: false
        ) == false)
        #expect(WorkspaceEditFileOperations.applyRenameFile(
            oldURI: a.absoluteString, newURI: b.absoluteString, overwrite: false, ignoreIfExists: true
        ) == true)

        // 新文件已存在
        FileManager.default.createFile(atPath: a.path, contents: nil)
        FileManager.default.createFile(atPath: b.path, contents: nil)
        #expect(WorkspaceEditFileOperations.applyRenameFile(
            oldURI: a.absoluteString, newURI: b.absoluteString, overwrite: false, ignoreIfExists: false
        ) == false)
        #expect(WorkspaceEditFileOperations.applyRenameFile(
            oldURI: a.absoluteString, newURI: b.absoluteString, overwrite: false, ignoreIfExists: true
        ) == true)
        #expect(WorkspaceEditFileOperations.applyRenameFile(
            oldURI: a.absoluteString, newURI: b.absoluteString, overwrite: true, ignoreIfExists: false
        ) == true)
        #expect(!FileManager.default.fileExists(atPath: a.path))
    }

    @Test("delete handles directories and ignoreIfNotExists")
    func deleteBranches() {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        // 不存在
        #expect(WorkspaceEditFileOperations.applyDeleteFile(
            uri: root.appendingPathComponent("none.swift").absoluteString,
            recursive: false, ignoreIfNotExists: false
        ) == false)
        #expect(WorkspaceEditFileOperations.applyDeleteFile(
            uri: root.appendingPathComponent("none.swift").absoluteString,
            recursive: false, ignoreIfNotExists: true
        ) == true)

        // 空目录非递归可删
        let emptyDir = root.appendingPathComponent("empty")
        try? FileManager.default.createDirectory(at: emptyDir, withIntermediateDirectories: true)
        #expect(WorkspaceEditFileOperations.applyDeleteFile(
            uri: emptyDir.absoluteString, recursive: false, ignoreIfNotExists: false
        ))

        // 非空目录非递归不可删
        let fullDir = root.appendingPathComponent("full")
        try? FileManager.default.createDirectory(
            at: fullDir.appendingPathComponent("sub"), withIntermediateDirectories: true
        )
        #expect(!WorkspaceEditFileOperations.applyDeleteFile(
            uri: fullDir.absoluteString, recursive: false, ignoreIfNotExists: false
        ))
        #expect(WorkspaceEditFileOperations.applyDeleteFile(
            uri: fullDir.absoluteString, recursive: true, ignoreIfNotExists: false
        ))
        #expect(!FileManager.default.fileExists(atPath: fullDir.path))
    }

    @Test("executor applies create/rename/delete off the main thread")
    func executorRoundTrip() async {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let executor = WorkspaceEditFileOperationsExecutor()

        let file = root.appendingPathComponent("created.swift")
        #expect(await executor.applyCreateFile(
            uri: file.absoluteString, overwrite: false, ignoreIfExists: false
        ))
        #expect(FileManager.default.fileExists(atPath: file.path))

        let moved = root.appendingPathComponent("moved.swift")
        #expect(await executor.applyRenameFile(
            oldURI: file.absoluteString, newURI: moved.absoluteString, overwrite: false, ignoreIfExists: false
        ))
        #expect(!FileManager.default.fileExists(atPath: file.path))

        #expect(await executor.applyDeleteFile(
            uri: moved.absoluteString, recursive: false, ignoreIfNotExists: false
        ))
        #expect(!FileManager.default.fileExists(atPath: moved.path))
    }
}

@Suite("EditorAutoSaveMode")
struct EditorAutoSaveModeTests {
    @Test("policy predicates match VS Code semantics")
    func policyPredicates() {
        #expect(!EditorAutoSaveMode.off.requiresAfterDelayScheduling)
        #expect(EditorAutoSaveMode.afterDelay.requiresAfterDelayScheduling)
        #expect(!EditorAutoSaveMode.onFocusChange.requiresAfterDelayScheduling)

        #expect(EditorAutoSaveMode.onFocusChange.respondsToFocusChange)
        #expect(EditorAutoSaveMode.onWindowChange.respondsToFocusChange)
        #expect(!EditorAutoSaveMode.off.respondsToFocusChange)

        #expect(EditorAutoSaveMode.onWindowChange.respondsToWindowChange)
        #expect(!EditorAutoSaveMode.onFocusChange.respondsToWindowChange)
    }

    @Test("display names are unique and non-empty")
    func displayNames() {
        let names = EditorAutoSaveMode.allCases.map(\.displayName)
        #expect(names.count == Set(names).count)
        #expect(names.allSatisfy { !$0.isEmpty })
    }
}
