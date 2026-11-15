#if canImport(XCTest)
import Foundation
import XCTest
@testable import EditorService

/// 回归 #396：Auto Save 关闭时切换文件不得丢失未保存的正文。
/// 会话必须随编辑持续保存脏正文快照，切回（含后退/前进）时用它
/// 替代磁盘内容，并恢复脏标记；保存成功后快照必须清空。
@MainActor
final class EditorDirtyBodyRetentionTests: XCTestCase {
    private func makeService() -> EditorService {
        EditorService(editorExtensionRegistry: EditorExtensionRegistry())
    }

    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("EditorDirtyBodyRetentionTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func editCurrentDocument(_ service: EditorService, to text: String) {
        let result = service.state.documentController.replaceText(text)
        service.state.content = service.state.documentController.textStorage
        service.state.totalLines = result.snapshot.text.filter { $0 == "\n" }.count + 1
        service.state.notifyContentChangedAfterSynchronizedEdit(using: text)
    }

    func testSwitchingBackRestoresUnsavedBody() async throws {
        let service = makeService()
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let aURL = directory.appendingPathComponent("DirtyA.swift")
        let bURL = directory.appendingPathComponent("DirtyB.swift")
        let diskA = "let a = 1\n"
        let editedA = "let a = 1\nlet unsaved = 42\n"
        try diskA.write(to: aURL, atomically: true, encoding: .utf8)
        try "let b = 2\n".write(to: bURL, atomically: true, encoding: .utf8)

        service.sessions.open(at: aURL)
        try await waitUntil("A loaded") {
            service.files.currentFileURL == aURL && service.files.content?.string == diskA
        }

        editCurrentDocument(service, to: editedA)
        XCTAssertTrue(service.files.hasUnsavedChanges)
        let sessionA = try XCTUnwrap(service.sessions.activeSession)
        XCTAssertEqual(sessionA.dirtyBody, editedA, "编辑后脏正文必须随会话同步落快照")

        service.sessions.open(at: bURL)
        try await waitUntil("B loaded") {
            service.files.currentFileURL == bURL && service.files.content?.string == "let b = 2\n"
        }

        service.sessions.open(at: aURL)
        try await waitUntil("A loaded again") {
            service.files.currentFileURL == aURL
        }

        XCTAssertEqual(service.files.content?.string, editedA, "切回文件必须恢复未保存的正文，而不是磁盘内容")
        XCTAssertTrue(service.files.hasUnsavedChanges, "恢复脏正文后必须保持脏标记")
        XCTAssertEqual(try String(contentsOf: aURL, encoding: .utf8), diskA, "恢复过程不得写磁盘")

        // 持久化基线必须是磁盘内容：恢复后的下一次内容同步仍应判定为脏，
        // 且随后的保存能把脏正文真正写回磁盘。
        service.state.notifyContentChangedAfterSynchronizedEdit(using: editedA)
        XCTAssertTrue(service.files.hasUnsavedChanges, "恢复脏正文后再次同步不得把脏标记误清为干净")

        service.commands.performCommand(id: "builtin.save")
        try await waitUntil("save finished") {
            !service.files.hasUnsavedChanges
        }
        XCTAssertEqual(try String(contentsOf: aURL, encoding: .utf8), editedA, "保存必须把恢复的脏正文写回磁盘")
    }

    func testSavingClearsDirtyBodyAndSwitchBackLoadsDisk() async throws {
        let service = makeService()
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let aURL = directory.appendingPathComponent("SavedA.swift")
        let bURL = directory.appendingPathComponent("SavedB.swift")
        let savedA = "let a = 1\nlet saved = 7\n"
        try "let a = 1\n".write(to: aURL, atomically: true, encoding: .utf8)
        try "let b = 2\n".write(to: bURL, atomically: true, encoding: .utf8)

        service.sessions.open(at: aURL)
        try await waitUntil("A loaded") {
            service.files.currentFileURL == aURL
        }

        editCurrentDocument(service, to: savedA)
        service.commands.performCommand(id: "builtin.save")
        try await waitUntil("save finished") {
            !service.files.hasUnsavedChanges
        }
        let sessionA = try XCTUnwrap(service.sessions.activeSession)
        XCTAssertNil(sessionA.dirtyBody, "保存成功后必须清空脏正文快照")

        service.sessions.open(at: bURL)
        try await waitUntil("B loaded") {
            service.files.currentFileURL == bURL
        }

        service.sessions.open(at: aURL)
        try await waitUntil("A loaded again") {
            service.files.currentFileURL == aURL
        }

        XCTAssertEqual(service.files.content?.string, savedA)
        XCTAssertFalse(service.files.hasUnsavedChanges, "已保存的文件切回后不得被误标为脏")
    }

    func testCleanFileSwitchKeepsDiskContent() async throws {
        let service = makeService()
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let aURL = directory.appendingPathComponent("CleanA.swift")
        let bURL = directory.appendingPathComponent("CleanB.swift")
        let diskA = "let a = 1\n"
        try diskA.write(to: aURL, atomically: true, encoding: .utf8)
        try "let b = 2\n".write(to: bURL, atomically: true, encoding: .utf8)

        service.sessions.open(at: aURL)
        try await waitUntil("A loaded") {
            service.files.currentFileURL == aURL && service.files.content?.string == diskA
        }

        service.sessions.open(at: bURL)
        try await waitUntil("B loaded") {
            service.files.currentFileURL == bURL
        }

        service.sessions.open(at: aURL)
        try await waitUntil("A loaded again") {
            service.files.currentFileURL == aURL
        }

        XCTAssertEqual(service.files.content?.string, diskA)
        XCTAssertFalse(service.files.hasUnsavedChanges)
    }

    func testRevertedEditIsTreatedAsCleanAfterSwitchBack() async throws {
        let service = makeService()
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let aURL = directory.appendingPathComponent("RevertA.swift")
        let bURL = directory.appendingPathComponent("RevertB.swift")
        let diskA = "let a = 1\n"
        try diskA.write(to: aURL, atomically: true, encoding: .utf8)
        try "let b = 2\n".write(to: bURL, atomically: true, encoding: .utf8)

        service.sessions.open(at: aURL)
        try await waitUntil("A loaded") {
            service.files.currentFileURL == aURL && service.files.content?.string == diskA
        }

        editCurrentDocument(service, to: "let a = 999\n")
        editCurrentDocument(service, to: diskA)

        service.sessions.open(at: bURL)
        try await waitUntil("B loaded") {
            service.files.currentFileURL == bURL
        }

        service.sessions.open(at: aURL)
        try await waitUntil("A loaded again") {
            service.files.currentFileURL == aURL
        }

        XCTAssertEqual(service.files.content?.string, diskA)
        XCTAssertFalse(service.files.hasUnsavedChanges, "正文已改回磁盘内容，切回后不应误标为脏")

        // 构造过期快照：dirtyBody 非空但与磁盘一致（如外部进程已把同样的内容写盘）。
        // 加载时必须按磁盘内容判定为干净，而不是盲目信任快照。
        let sessionA = try XCTUnwrap(service.sessions.activeSession)
        sessionA.dirtyBody = diskA

        service.sessions.open(at: bURL)
        try await waitUntil("B loaded again") {
            service.files.currentFileURL == bURL
        }

        service.sessions.open(at: aURL)
        try await waitUntil("A loaded third time") {
            service.files.currentFileURL == aURL
        }

        XCTAssertEqual(service.files.content?.string, diskA)
        XCTAssertFalse(service.files.hasUnsavedChanges, "与磁盘一致的脏正文快照不得把文件误标为脏")
    }

    func testGoBackRestoresUnsavedBody() async throws {
        let service = makeService()
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let aURL = directory.appendingPathComponent("NavDirtyA.swift")
        let bURL = directory.appendingPathComponent("NavDirtyB.swift")
        let editedA = "let a = 1\nlet unsavedNav = 9\n"
        try "let a = 1\n".write(to: aURL, atomically: true, encoding: .utf8)
        try "let b = 2\n".write(to: bURL, atomically: true, encoding: .utf8)

        service.sessions.open(at: aURL)
        try await waitUntil("A loaded") {
            service.files.currentFileURL == aURL
        }

        editCurrentDocument(service, to: editedA)

        service.sessions.open(at: bURL)
        try await waitUntil("B loaded") {
            service.files.currentFileURL == bURL
        }

        let entry = try XCTUnwrap(service.sessions.goBack())
        XCTAssertEqual(entry.fileURL, aURL)
        try await waitUntil("A loaded after goBack") {
            service.files.currentFileURL == aURL
        }

        XCTAssertEqual(service.files.content?.string, editedA, "后退必须恢复未保存的正文，历史快照副本不得携带过期正文")
        XCTAssertTrue(service.files.hasUnsavedChanges)
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
}
#endif