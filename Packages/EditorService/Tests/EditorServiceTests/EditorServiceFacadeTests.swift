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

    func testOpenFileCreatesAndActivatesSession() {
        let service = makeService()
        let url = makeURL("Facade-A.swift")

        let session = service.openFile(at: url)

        XCTAssertNotNil(session)
        XCTAssertEqual(service.tabs.count, 1)
        XCTAssertEqual(service.activeSessionID, session?.id)
        XCTAssertEqual(service.session(for: session!.id)?.fileURL, url)
    }

    func testOpenFileReusesExistingSessionForSameURL() {
        let service = makeService()
        let url = makeURL("Facade-B.swift")

        let first = service.openFile(at: url)
        let second = service.openFile(at: url)

        XCTAssertEqual(service.tabs.count, 1)
        XCTAssertEqual(first?.id, second?.id)
        XCTAssertEqual(service.activeSessionID, first?.id)
    }

    func testCloseOtherSessionsKeepsOnlyRequestedSession() {
        let service = makeService()
        let a = service.openFile(at: makeURL("Facade-C-A.swift"))!
        _ = service.openFile(at: makeURL("Facade-C-B.swift"))
        _ = service.openFile(at: makeURL("Facade-C-C.swift"))

        _ = service.closeOtherSessions(keeping: a.id)

        XCTAssertEqual(service.tabs.count, 1)
        XCTAssertEqual(service.activeSessionID, a.id)
        XCTAssertNotNil(service.session(for: a.id))
    }

    func testNavigationBackAndForwardSwitchesActiveSession() {
        let service = makeService()
        let a = service.openFile(at: makeURL("Facade-D-A.swift"))!
        let b = service.openFile(at: makeURL("Facade-D-B.swift"))!

        let back = service.goBack()
        XCTAssertEqual(back?.id, a.id)
        XCTAssertEqual(service.activeSessionID, a.id)

        let forward = service.goForward()
        XCTAssertEqual(forward?.id, b.id)
        XCTAssertEqual(service.activeSessionID, b.id)
    }

    func testCloseAllSessionsClearsTabsAndActiveSession() {
        let service = makeService()
        _ = service.openFile(at: makeURL("Facade-E-A.swift"))
        _ = service.openFile(at: makeURL("Facade-E-B.swift"))

        service.closeAllSessions()

        XCTAssertTrue(service.tabs.isEmpty)
        XCTAssertNil(service.activeSessionID)
        XCTAssertNil(service.activeSession)
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

        service.open(at: fileURL)
        try await waitUntil("file loaded") {
            service.currentFileURL == fileURL && service.content?.string == "struct SaveView {}\n"
        }

        let updated = "struct SaveView { let value = 1 }\n"
        let result = service.state.documentController.replaceText(updated)
        service.state.content = service.state.documentController.textStorage
        service.state.totalLines = result.snapshot.text.filter { $0 == "\n" }.count + 1
        service.state.notifyContentChangedAfterSynchronizedEdit(using: updated)
        let previousSaveRevision = service.saveRevision

        XCTAssertTrue(service.hasUnsavedChanges)

        service.performCommand(id: "builtin.save")

        try await waitUntil("save finished") {
            !service.hasUnsavedChanges
        }

        let onDisk = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertEqual(onDisk, updated)
        XCTAssertEqual(service.content?.string, updated)
        XCTAssertFalse(service.hasUnsavedChanges)
        XCTAssertEqual(service.saveRevision, previousSaveRevision + 1)
    }

    func testReplaceCurrentDocumentTextUpdatesContentAndDirtyState() async throws {
        let service = makeService()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("EditorServiceFacadeTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let fileURL = directory.appendingPathComponent("Replace.swift")
        try "struct ReplaceView {}\n".write(to: fileURL, atomically: true, encoding: .utf8)

        service.open(at: fileURL)
        try await waitUntil("file loaded") {
            service.currentFileURL == fileURL && service.content?.string == "struct ReplaceView {}\n"
        }

        let updated = "struct ReplaceView { let value = 1 }\n"
        let didReplace = service.replaceCurrentDocumentText(updated, reason: "test_replace_document")

        XCTAssertTrue(didReplace)
        XCTAssertEqual(service.content?.string, updated)
        XCTAssertTrue(service.hasUnsavedChanges)
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
