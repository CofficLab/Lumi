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

    func testRefreshProjectContextClosesPreviousContextWhenSwitchingToNonXcodeProject() async {
        let registry = EditorExtensionRegistry()
        let capability = TrackingProjectContextCapability(handledProjectPaths: ["/tmp/Lumi"])
        registry.registerProjectContextCapability(capability)

        let service = EditorService(editorExtensionRegistry: registry)

        await service.refreshProjectContext(for: "/tmp/Lumi")
        XCTAssertEqual(capability.openedPaths, ["/tmp/Lumi"])
        XCTAssertEqual(capability.closeCount, 0)

        await service.refreshProjectContext(for: "/tmp/GitOK")
        XCTAssertEqual(
            capability.closeCount,
            1,
            "Switching away from an Xcode project must close the previous context even when the new project has no capability"
        )
        XCTAssertEqual(capability.openedPaths, ["/tmp/Lumi"])
        XCTAssertEqual(service.projectRootPath, "/tmp/GitOK")
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

    /// 回归 #980：切回一个已加载过的文件时，异步加载完成后必须恢复该 Session
    /// 保存的视图状态，而不是把切换前的当前视图状态同步进目标 Session。
    func testReopeningExistingSessionRestoresSavedStateAfterAsyncLoad() async throws {
        let service = makeService()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("EditorServiceFacadeTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let aURL = directory.appendingPathComponent("RestoreA.swift")
        let bURL = directory.appendingPathComponent("RestoreB.swift")
        let aContent = (1...30).map { "let value\($0) = \($0)" }.joined(separator: "\n") + "\n"
        try aContent.write(to: aURL, atomically: true, encoding: .utf8)
        try "let b = 2\n".write(to: bURL, atomically: true, encoding: .utf8)

        service.sessions.open(at: aURL)
        try await waitUntil("A loaded") {
            service.files.currentFileURL == aURL && service.files.content?.string == aContent
        }

        // 模拟 A 的 Session 里已保存的光标（用户停在更深的第 20 行）。
        // 真实会话会同时保存 multiCursorState 与 viewState.cursorPositions，
        // 这里按同样结构构造，避免只写行号走不到真实恢复路径。
        let line20Offset = (aContent as NSString).range(of: "let value20").location
        let cursor = CursorPosition(line: 20, column: 1)
        let aSession = try XCTUnwrap(service.sessions.activeSession)
        aSession.multiCursorState = MultiCursorState(
            primary: MultiCursorSelection(location: line20Offset, length: 0)
        )
        aSession.viewState = EditorViewState(
            primaryCursorLine: 20,
            primaryCursorColumn: 1,
            cursorPositions: [cursor]
        )

        // 切到 B，再切回 A：此时 A 需要走异步重新加载路径。
        service.sessions.open(at: bURL)
        try await waitUntil("B loaded") {
            service.files.currentFileURL == bURL
        }

        service.sessions.open(at: aURL)
        try await waitUntil("A loaded again") {
            service.files.currentFileURL == aURL && service.files.content?.string == aContent
        }

        XCTAssertEqual(service.sessions.activeSessionID, aSession.id)
        XCTAssertEqual(service.editing.cursorLine, 20, "加载完成后应恢复 A Session 保存的光标行")
        XCTAssertEqual(service.editing.cursorColumn, 1)
    }

    /// 回归 #981：后退/前进不能只切 `activeSessionID`，必须加载目标文件并应用
    /// 历史项快照，否则选中的 Session 与屏幕正文分裂。
    func testGoBackLoadsTargetFileAndAppliesHistorySnapshot() async throws {
        let service = makeService()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("EditorNavigation-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let aURL = directory.appendingPathComponent("NavA.swift")
        let bURL = directory.appendingPathComponent("NavB.swift")
        let aContent = (1...30).map { "let navValue\($0) = \($0)" }.joined(separator: "\n") + "\n"
        try aContent.write(to: aURL, atomically: true, encoding: .utf8)
        try "let b = 2\n".write(to: bURL, atomically: true, encoding: .utf8)

        service.sessions.open(at: aURL)
        try await waitUntil("A loaded") {
            service.files.currentFileURL == aURL && service.files.content?.string == aContent
        }
        let sessionA = try XCTUnwrap(service.sessions.activeSession)

        // 让 A 的历史项记录一个第 15 行的快照（syncActiveSession 会替换当前历史项）。
        let snapshot = EditorSession(fileURL: aURL)
        let offset = (aContent as NSString).range(of: "let navValue15").location
        snapshot.multiCursorState = MultiCursorState(
            primary: MultiCursorSelection(location: offset, length: 0)
        )
        snapshot.viewState = EditorViewState(
            primaryCursorLine: 15,
            primaryCursorColumn: 1,
            cursorPositions: [CursorPosition(line: 15, column: 1)]
        )
        service.sessions.syncActiveSession(from: snapshot)

        service.sessions.open(at: bURL)
        try await waitUntil("B loaded") {
            service.files.currentFileURL == bURL
        }

        let entry = try XCTUnwrap(service.sessions.goBack())
        XCTAssertEqual(entry.id, sessionA.id)
        try await waitUntil("A loaded after goBack") {
            service.files.currentFileURL == aURL && service.files.content?.string == aContent
        }

        XCTAssertEqual(service.sessions.activeSessionID, sessionA.id)
        XCTAssertEqual(service.files.currentFileURL, aURL)
        XCTAssertEqual(service.files.content?.string, aContent)
        XCTAssertEqual(service.editing.cursorLine, 15, "后退应应用历史项保存的光标")
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

@MainActor
private final class TrackingProjectContextCapability: SuperEditorProjectContextCapability {
    let id = "tracking.project.context"
    private let handledProjectPaths: Set<String>
    private(set) var closeCount = 0
    private(set) var openedPaths: [String] = []

    init(handledProjectPaths: Set<String>) {
        self.handledProjectPaths = handledProjectPaths
    }

    func canHandleProject(at path: String?) -> Bool {
        guard let path else { return false }
        return handledProjectPaths.contains(path)
    }

    func projectOpened(at path: String) async {
        openedPaths.append(path)
    }

    func projectClosed() {
        closeCount += 1
    }

    func resyncProjectContext() async {}

    func makeEditorContextSnapshot(currentFileURL: URL?) -> EditorProjectContextSnapshot? {
        nil
    }

    func updateLatestEditorSnapshot(_ snapshot: EditorProjectContextSnapshot?) {}
}
#endif
