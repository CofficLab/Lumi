#if canImport(XCTest)
import Foundation
import ProviderEditor
import XCTest
@testable import EditorService

/// 回归 #589：V2 `editor.documents.reload` / `revert` 必须真正重新应用磁盘内容。
/// 同一 URL 的常规加载会跳过 buffer 替换（保护未保存正文，#396），
/// 但 reload / revert 的语义就是丢弃内存编辑、回到磁盘内容并清掉脏标记。
@MainActor
final class EditorDocumentReloadRevertTests: XCTestCase {
    private var service: EditorService!
    private var adapter: EditorProvidingV2Adapter!

    override func setUp() {
        super.setUp()
        service = EditorService(editorExtensionRegistry: EditorExtensionRegistry())
        adapter = EditorProvidingV2Adapter(service: service)
    }

    override func tearDown() {
        adapter = nil
        service = nil
        super.tearDown()
    }

    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("EditorReloadRevertTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func editCurrentDocument(to text: String) {
        let result = service.state.documentController.replaceText(text)
        service.state.content = service.state.documentController.textStorage
        service.state.totalLines = result.snapshot.text.filter { $0 == "\n" }.count + 1
        service.state.notifyContentChangedAfterSynchronizedEdit(using: text)
    }

    private func openDocument(at url: URL) async throws -> EditorDocumentID {
        let sessionID = try await adapter.documents.open(EditorOpenRequest(uri: url, kind: .activate))
        return adapter.documentID(for: sessionID.rawValue)
    }

    private func waitUntil(
        _ description: String,
        timeout: TimeInterval = 2,
        condition: @escaping @MainActor () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return
            }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTFail("Timed out waiting for \(description)")
    }

    // MARK: - revert

    func testRevertDiscardsUnsavedEditsAndClearsDirtySnapshot() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Revert.swift")
        let disk = "let a = 1\n"
        try disk.write(to: url, atomically: true, encoding: .utf8)

        let documentID = try await openDocument(at: url)
        editCurrentDocument(to: "let a = 1\nlet unsaved = 42\n")
        XCTAssertTrue(service.files.hasUnsavedChanges)

        try await adapter.documents.revert(documentID: documentID)

        XCTAssertEqual(service.files.content?.string, disk, "revert 必须重新应用磁盘内容")
        XCTAssertFalse(service.files.hasUnsavedChanges, "revert 必须清掉脏标记")
        XCTAssertFalse(service.files.isFileLoadInProgress, "revert 返回时加载必须已完成")
        XCTAssertNil(service.sessions.activeSession?.dirtyBody, "revert 必须清空会话的脏正文快照")
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), disk, "revert 不得写磁盘")
    }

    func testRevertThenSwitchBackDoesNotResurrectDiscardedEdits() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let aURL = directory.appendingPathComponent("RevertA.swift")
        let bURL = directory.appendingPathComponent("RevertB.swift")
        let diskA = "let a = 1\n"
        try diskA.write(to: aURL, atomically: true, encoding: .utf8)
        try "let b = 2\n".write(to: bURL, atomically: true, encoding: .utf8)

        let documentID = try await openDocument(at: aURL)
        editCurrentDocument(to: "let a = 1\nlet discarded = 9\n")
        try await adapter.documents.revert(documentID: documentID)

        service.sessions.open(at: bURL)
        try await waitUntil("B loaded") {
            self.service.files.currentFileURL == bURL && self.service.files.content?.string == "let b = 2\n"
        }
        service.sessions.open(at: aURL)
        try await waitUntil("A loaded again") {
            self.service.files.currentFileURL == aURL
        }

        XCTAssertEqual(service.files.content?.string, diskA, "revert 丢弃的编辑不得在切回时复活")
        XCTAssertFalse(service.files.hasUnsavedChanges)
    }

    // MARK: - reload

    func testReloadAppliesExternalDiskChangeToCleanBuffer() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("ReloadClean.swift")
        try "let v = 1\n".write(to: url, atomically: true, encoding: .utf8)

        let documentID = try await openDocument(at: url)
        let external = "let v = 2\n"
        try external.write(to: url, atomically: true, encoding: .utf8)

        try await adapter.documents.reload(documentID: documentID)

        XCTAssertEqual(service.files.content?.string, external, "reload 必须应用磁盘上的新内容")
        XCTAssertFalse(service.files.hasUnsavedChanges)
        XCTAssertNil(service.sessions.activeSession?.dirtyBody)
    }

    func testReloadAppliesExternalDiskChangeOverDirtyBuffer() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("ReloadDirty.swift")
        try "let v = 1\n".write(to: url, atomically: true, encoding: .utf8)

        let documentID = try await openDocument(at: url)
        editCurrentDocument(to: "let v = 1\nlet unsaved = 7\n")
        XCTAssertTrue(service.files.hasUnsavedChanges)
        let external = "let v = 3\n"
        try external.write(to: url, atomically: true, encoding: .utf8)

        try await adapter.documents.reload(documentID: documentID)

        XCTAssertEqual(service.files.content?.string, external, "reload 必须用磁盘内容替换脏 buffer")
        XCTAssertFalse(service.files.hasUnsavedChanges)
        XCTAssertNil(service.sessions.activeSession?.dirtyBody)

        // 持久化基线必须同步到磁盘内容：随后的编辑仍能被识别为脏并保存。
        editCurrentDocument(to: external + "let next = 4\n")
        XCTAssertTrue(service.files.hasUnsavedChanges, "reload 后再次编辑必须重新判定为脏")
    }

    func testReloadClearsStaleExternalConflictFlag() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("ReloadConflict.swift")
        try "let v = 1\n".write(to: url, atomically: true, encoding: .utf8)

        let documentID = try await openDocument(at: url)
        editCurrentDocument(to: "let v = 1\nlet unsaved = 5\n")
        let external = "let v = 8\n"
        try external.write(to: url, atomically: true, encoding: .utf8)
        service.state.reloadIfFileChangedExternally(url: url, currentModDate: Date())
        try await waitUntil("external conflict registered") {
            self.service.files.hasExternalFileConflict
        }

        try await adapter.documents.reload(documentID: documentID)

        XCTAssertFalse(service.files.hasExternalFileConflict, "buffer 已与磁盘一致，冲突提示必须清除")
        XCTAssertEqual(service.files.content?.string, external)
    }

    // MARK: - 契约守卫

    func testRevertOnBackgroundDocumentThrowsCapabilityUnavailable() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let aURL = directory.appendingPathComponent("GuardA.swift")
        let bURL = directory.appendingPathComponent("GuardB.swift")
        try "let a = 1\n".write(to: aURL, atomically: true, encoding: .utf8)
        try "let b = 2\n".write(to: bURL, atomically: true, encoding: .utf8)

        let aDocumentID = try await openDocument(at: aURL)
        _ = try await openDocument(at: bURL)

        do {
            try await adapter.documents.revert(documentID: aDocumentID)
            XCTFail("非活动文档的 revert 必须抛出能力不可用")
        } catch let error as EditorContractError {
            XCTAssertEqual(error, .capabilityUnavailable(feature: "editor.documents.reload"))
        }
        XCTAssertEqual(service.files.content?.string, "let b = 2\n", "被拒绝的 revert 不得改动活动文档")
    }

    func testReloadOnUnknownDocumentThrowsDocumentNotFound() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("GuardUnknown.swift")
        try "let a = 1\n".write(to: url, atomically: true, encoding: .utf8)
        _ = try await openDocument(at: url)

        let unknown = EditorDocumentID.makeUnique()
        do {
            try await adapter.documents.reload(documentID: unknown)
            XCTFail("未知文档的 reload 必须抛出文档不存在")
        } catch let error as EditorContractError {
            XCTAssertEqual(error, .documentNotFound(unknown))
        }
    }

    // MARK: - 身份校验

    func testForcedReloadInFlightDoesNotPolluteSwitchedTab() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let aURL = directory.appendingPathComponent("RaceA.swift")
        let bURL = directory.appendingPathComponent("RaceB.swift")
        try "let a = 1\n".write(to: aURL, atomically: true, encoding: .utf8)
        let diskB = "let b = 2\n"
        try diskB.write(to: bURL, atomically: true, encoding: .utf8)

        _ = try await openDocument(at: aURL)
        editCurrentDocument(to: "let a = 1\nlet unsavedRace = 3\n")

        // 强制重读已启动但尚未返回：同步切到 B，不让出主 actor。
        service.files.reloadCurrentFileFromDisk()
        service.sessions.open(at: bURL)
        try await waitUntil("B loaded") {
            self.service.files.currentFileURL == bURL && self.service.files.content?.string == diskB
        }
        try await Task.sleep(nanoseconds: 400_000_000)

        XCTAssertEqual(service.files.currentFileURL, bURL)
        XCTAssertEqual(service.files.content?.string, diskB, "A 的强制重读结果不得写进 B 的 buffer")
        XCTAssertFalse(service.files.hasUnsavedChanges)
    }
}
#endif
