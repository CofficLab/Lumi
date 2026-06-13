#if canImport(XCTest)
import Foundation
import XCTest
@testable import EditorService

@MainActor
final class EditorServiceFacadeTests: XCTestCase {
    private func makeService() -> EditorService {
        EditorService(editorExtensionRegistry: EditorExtensionRegistry())
    }

    private func makeURL(_ name: String) -> URL {
        URL(fileURLWithPath: "/tmp/\(name)")
    }

    func testOpenFileSessionOnlySignalsPendingContentLoadForActiveSession() {
        let service = makeService()
        let url = makeURL("Facade-SessionOnly.swift")

        let session = service.sessions.openFile(at: url)

        XCTAssertNotNil(session)
        XCTAssertEqual(service.sessions.activeSessionID, session?.id)
        XCTAssertNil(service.files.currentFileURL)
        XCTAssertFalse(service.files.canPreview)
        XCTAssertTrue(
            service.files.isFileLoadInProgress,
            "活跃 session 在 buffer 就绪前应标记为加载中，避免 UI 误判为不支持的文件"
        )
    }

    func testOpenFileCreatesAndActivatesSession() {
        let service = makeService()
        let url = makeURL("Facade-A.swift")

        let session = service.sessions.openFile(at: url)

        XCTAssertNotNil(session)
        XCTAssertEqual(service.sessions.tabs.count, 1)
        XCTAssertEqual(service.sessions.activeSessionID, session?.id)
        XCTAssertEqual(service.sessions.session(for: session!.id)?.fileURL, url)
    }

    func testOpenFileReusesExistingSessionForSameURL() {
        let service = makeService()
        let url = makeURL("Facade-B.swift")

        let first = service.sessions.openFile(at: url)
        let second = service.sessions.openFile(at: url)

        XCTAssertEqual(service.sessions.tabs.count, 1)
        XCTAssertEqual(first?.id, second?.id)
        XCTAssertEqual(service.sessions.activeSessionID, first?.id)
    }

    func testCloseOtherSessionsKeepsOnlyRequestedSession() {
        let service = makeService()
        let a = service.sessions.openFile(at: makeURL("Facade-C-A.swift"))!
        _ = service.sessions.openFile(at: makeURL("Facade-C-B.swift"))
        _ = service.sessions.openFile(at: makeURL("Facade-C-C.swift"))

        _ = service.sessions.closeOtherSessions(keeping: a.id)

        XCTAssertEqual(service.sessions.tabs.count, 1)
        XCTAssertEqual(service.sessions.activeSessionID, a.id)
        XCTAssertNotNil(service.sessions.session(for: a.id))
    }

    func testNavigationBackAndForwardSwitchesActiveSession() {
        let service = makeService()
        let a = service.sessions.openFile(at: makeURL("Facade-D-A.swift"))!
        let b = service.sessions.openFile(at: makeURL("Facade-D-B.swift"))!

        let back = service.sessions.goBack()
        XCTAssertEqual(back?.id, a.id)
        XCTAssertEqual(service.sessions.activeSessionID, a.id)

        let forward = service.sessions.goForward()
        XCTAssertEqual(forward?.id, b.id)
        XCTAssertEqual(service.sessions.activeSessionID, b.id)
    }

    func testCloseAllSessionsClearsTabsAndActiveSession() {
        let service = makeService()
        _ = service.sessions.openFile(at: makeURL("Facade-E-A.swift"))
        _ = service.sessions.openFile(at: makeURL("Facade-E-B.swift"))

        service.sessions.closeAllSessions()

        XCTAssertTrue(service.sessions.tabs.isEmpty)
        XCTAssertNil(service.sessions.activeSessionID)
        XCTAssertNil(service.sessions.activeSession)
    }

    func testSessionLookupMapToleratesDuplicateSessionIDs() {
        let sessionID = UUID()
        let first = EditorSession(id: sessionID, fileURL: makeURL("Facade-Duplicate-A.swift"))
        let duplicate = EditorSession(id: sessionID, fileURL: makeURL("Facade-Duplicate-B.swift"))
        let other = EditorSession(fileURL: makeURL("Facade-Duplicate-C.swift"))

        let sessionsByID = EditorSessionStore.sessionsByIDPreservingFirst([first, duplicate, other])

        XCTAssertIdentical(sessionsByID[sessionID], first)
        XCTAssertEqual(sessionsByID.count, 2)
        XCTAssertIdentical(sessionsByID[other.id], other)
    }

    func testBuiltinSavePersistsDirtyBufferAndClearsDirtyState() async throws {
        let service = makeService()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("EditorServiceFacadeTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let fileURL = directory.appendingPathComponent("Save.swift")
        try "struct SaveView {}\n".write(to: fileURL, atomically: true, encoding: .utf8)

        service.sessions.open(at: fileURL)
        try await waitUntil("file loaded") {
            service.files.currentFileURL == fileURL && service.files.content?.string == "struct SaveView {}\n"
        }

        let updated = "struct SaveView { let value = 1 }\n"
        let result = service.state.documentController.replaceText(updated)
        service.state.content = service.state.documentController.textStorage
        service.state.totalLines = result.snapshot.text.filter { $0 == "\n" }.count + 1
        service.state.notifyContentChangedAfterSynchronizedEdit(using: updated)
        let previousSaveRevision = service.files.saveRevision

        XCTAssertTrue(service.files.hasUnsavedChanges)

        service.commands.performCommand(id: "builtin.save")

        try await waitUntil("save finished") {
            !service.files.hasUnsavedChanges
        }

        let onDisk = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertEqual(onDisk, updated)
        XCTAssertEqual(service.files.content?.string, updated)
        XCTAssertFalse(service.files.hasUnsavedChanges)
        XCTAssertEqual(service.files.saveRevision, previousSaveRevision + 1)
    }

    func testReplaceCurrentDocumentTextUpdatesContentAndDirtyState() async throws {
        let service = makeService()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("EditorServiceFacadeTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let fileURL = directory.appendingPathComponent("Replace.swift")
        try "struct ReplaceView {}\n".write(to: fileURL, atomically: true, encoding: .utf8)

        service.sessions.open(at: fileURL)
        try await waitUntil("file loaded") {
            service.files.currentFileURL == fileURL && service.files.content?.string == "struct ReplaceView {}\n"
        }

        let updated = "struct ReplaceView { let value = 1 }\n"
        let didReplace = service.files.replaceCurrentDocumentText(updated, reason: "test_replace_document")

        XCTAssertTrue(didReplace)
        XCTAssertEqual(service.files.content?.string, updated)
        XCTAssertTrue(service.files.hasUnsavedChanges)
    }

    func testClearingEditorInvalidatesPendingFileLoads() async throws {
        let service = makeService()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("EditorServiceFacadeTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let fileURL = directory.appendingPathComponent("StaleLoad.swift")
        try "struct StaleLoad {}\n".write(to: fileURL, atomically: true, encoding: .utf8)

        service.files.loadFile(from: fileURL)
        service.files.loadFile(from: nil)

        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertNil(service.files.currentFileURL)
        XCTAssertNil(service.files.content)
        XCTAssertFalse(service.files.isFileLoadInProgress)
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
