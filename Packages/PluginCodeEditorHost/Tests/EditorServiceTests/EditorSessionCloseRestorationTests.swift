#if canImport(XCTest)
import Foundation
import ProviderEditor
import XCTest
@testable import EditorService

/// 回归 #588：关闭活跃 Session 后，store 选出的替补 Tab 必须真正被加载/恢复。
/// 修复前只有 `activeSessionID == nil` 才清空编辑器，其余情况下外部状态指向替补、
/// 屏幕正文与 `currentFileURL` 仍属于已关闭的文档（`closeOthers`/左右关闭同样缺失）。
@MainActor
final class EditorSessionCloseRestorationTests: XCTestCase {
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
            .appendingPathComponent("EditorCloseRestorationTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func write(_ text: String, to url: URL) throws {
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    private func editCurrentDocument(to text: String) {
        let result = service.state.documentController.replaceText(text)
        service.state.content = service.state.documentController.textStorage
        service.state.totalLines = result.snapshot.text.filter { $0 == "\n" }.count + 1
        service.state.notifyContentChangedAfterSynchronizedEdit(using: text)
    }

    private func openSession(at url: URL) async throws -> EditorSessionID {
        try await adapter.documents.open(EditorOpenRequest(uri: url, kind: .activate))
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

    // MARK: - close

    func testClosingActiveSessionRestoresReplacementTab() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let aURL = directory.appendingPathComponent("CloseA.swift")
        let bURL = directory.appendingPathComponent("CloseB.swift")
        let diskA = "let a = 1\n"
        try write(diskA, to: aURL)
        try write("let b = 2\n", to: bURL)

        let aID = try await openSession(at: aURL)
        let bID = try await openSession(at: bURL)
        XCTAssertEqual(service.files.currentFileURL, bURL)

        try await adapter.sessions.close(sessionID: bID, policy: .discardChanges)

        // close 返回时恢复必须已收尾：调用方无需再轮询即可读到替补 Tab 的正文。
        XCTAssertFalse(service.files.isFileLoadInProgress, "close 返回时替补加载必须已完成")
        XCTAssertEqual(service.sessions.activeSessionID, aID.rawValue)
        XCTAssertEqual(service.files.currentFileURL, aURL, "currentFileURL 不得停留在已关闭的 B")
        XCTAssertEqual(service.files.content?.string, diskA, "屏幕正文必须切到替补 A")
        XCTAssertEqual(service.sessions.tabs.map(\.sessionID), [aID.rawValue])
        XCTAssertEqual(adapter.sessions.state.groups.first?.activeSessionID, aID)
    }

    func testClosingActiveSessionRestoresReplacementUnsavedBody() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let aURL = directory.appendingPathComponent("CloseDirtyA.swift")
        let bURL = directory.appendingPathComponent("CloseDirtyB.swift")
        let diskA = "let a = 1\n"
        let editedA = "let a = 1\nlet unsaved = 42\n"
        try write(diskA, to: aURL)
        try write("let b = 2\n", to: bURL)

        _ = try await openSession(at: aURL)
        editCurrentDocument(to: editedA)
        let bID = try await openSession(at: bURL)

        try await adapter.sessions.close(sessionID: bID, policy: .discardChanges)

        XCTAssertEqual(service.files.currentFileURL, aURL)
        XCTAssertEqual(service.files.content?.string, editedA, "替补 A 的未保存正文必须一并恢复（#396）")
        XCTAssertTrue(service.files.hasUnsavedChanges)
        XCTAssertEqual(try String(contentsOf: aURL, encoding: .utf8), diskA, "恢复过程不得写磁盘")
    }

    func testClosingBackgroundSessionKeepsActiveBuffer() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let aURL = directory.appendingPathComponent("BackgroundA.swift")
        let bURL = directory.appendingPathComponent("BackgroundB.swift")
        let cURL = directory.appendingPathComponent("BackgroundC.swift")
        try write("let a = 1\n", to: aURL)
        try write("let b = 2\n", to: bURL)
        try write("let c = 3\n", to: cURL)

        let aID = try await openSession(at: aURL)
        let bID = try await openSession(at: bURL)
        let cSession = service.sessions.openFileSessionInBackground(at: cURL)
        let editedB = "let b = 2\nlet editing = 7\n"
        editCurrentDocument(to: editedB)

        try await adapter.sessions.close(sessionID: aID, policy: .discardChanges)

        XCTAssertEqual(service.sessions.activeSessionID, bID.rawValue)
        XCTAssertEqual(service.files.currentFileURL, bURL)
        XCTAssertEqual(service.files.content?.string, editedB, "不得用替补恢复覆盖正在编辑的正文")
        XCTAssertTrue(service.files.hasUnsavedChanges)

        // 门面层同步关闭另一个后台 Tab：活跃 Session 未变，不得启动任何加载
        // （否则会在用户毫无察觉时重读活动文件，磁盘已变/已删时还会丢正文）。
        _ = service.sessions.closeSession(id: cSession.id)
        XCTAssertFalse(service.files.isFileLoadInProgress, "关闭后台 Tab 不得触发任何加载")
        XCTAssertEqual(service.files.content?.string, editedB)
    }

    func testClosingLastSessionClearsEditor() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Last.swift")
        try write("let a = 1\n", to: url)
        let id = try await openSession(at: url)

        try await adapter.sessions.close(sessionID: id, policy: .discardChanges)

        XCTAssertNil(service.sessions.activeSessionID)
        XCTAssertNil(service.files.currentFileURL, "已无 Tab 时必须清空编辑器")
        XCTAssertNil(service.files.content)
        XCTAssertTrue(service.sessions.tabs.isEmpty)
    }

    func testRequireConfirmationLeavesBufferAndTabsIntact() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let aURL = directory.appendingPathComponent("ConfirmA.swift")
        let bURL = directory.appendingPathComponent("ConfirmB.swift")
        try write("let a = 1\n", to: aURL)
        try write("let b = 2\n", to: bURL)

        _ = try await openSession(at: aURL)
        let bID = try await openSession(at: bURL)
        let editedB = "let b = 2\nlet unsaved = 3\n"
        editCurrentDocument(to: editedB)

        do {
            try await adapter.sessions.close(sessionID: bID, policy: .requireConfirmation)
            XCTFail("脏文档在 requireConfirmation 下必须抛出待确认")
        } catch let error as EditorContractError {
            XCTAssertEqual(error, .closeRequiresConfirmation(bID))
        }

        XCTAssertEqual(service.sessions.activeSessionID, bID.rawValue)
        XCTAssertEqual(service.files.content?.string, editedB, "被拒绝的关闭不得改动正文")
        XCTAssertEqual(service.sessions.tabs.count, 2)
    }

    // MARK: - closeOthers / 左右关闭

    func testCloseOthersRestoresKeptTabWhenActiveIsClosed() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let aURL = directory.appendingPathComponent("OthersA.swift")
        let bURL = directory.appendingPathComponent("OthersB.swift")
        let cURL = directory.appendingPathComponent("OthersC.swift")
        let diskA = "let a = 1\n"
        try write(diskA, to: aURL)
        try write("let b = 2\n", to: bURL)
        try write("let c = 3\n", to: cURL)

        let aID = try await openSession(at: aURL)
        _ = try await openSession(at: bURL)
        _ = try await openSession(at: cURL)

        try await adapter.sessions.closeOthers(keeping: aID)

        XCTAssertFalse(service.files.isFileLoadInProgress)
        XCTAssertEqual(service.sessions.activeSessionID, aID.rawValue)
        XCTAssertEqual(service.files.currentFileURL, aURL, "closeOthers 关掉活跃 Tab 后必须恢复保留 Tab")
        XCTAssertEqual(service.files.content?.string, diskA)
        XCTAssertEqual(service.sessions.tabs.map(\.sessionID), [aID.rawValue])
    }

    func testCloseOthersKeepsBufferWhenKeptTabIsActive() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let aURL = directory.appendingPathComponent("OthersActiveA.swift")
        let bURL = directory.appendingPathComponent("OthersActiveB.swift")
        let diskA = "let a = 1\n"
        try write(diskA, to: aURL)
        try write("let b = 2\n", to: bURL)

        let aID = try await openSession(at: aURL)
        let editedA = "let a = 1\nlet editing = 5\n"
        editCurrentDocument(to: editedA)
        _ = service.sessions.openFileSessionInBackground(at: bURL)

        // 门面层同步关闭：保留 Tab 已是活跃 Tab，不得启动任何加载。
        _ = service.sessions.closeOtherSessions(keeping: aID.rawValue)
        XCTAssertFalse(service.files.isFileLoadInProgress, "保留 Tab 已是活跃 Tab 时不得重新加载")
        XCTAssertEqual(service.sessions.activeSessionID, aID.rawValue)
        XCTAssertEqual(service.files.content?.string, editedA)
        XCTAssertTrue(service.files.hasUnsavedChanges)

        try await adapter.sessions.closeOthers(keeping: aID)

        XCTAssertEqual(service.files.content?.string, editedA, "契约路径同样不得覆盖正在编辑的正文")
        XCTAssertEqual(service.sessions.tabs.map(\.sessionID), [aID.rawValue])
    }

    func testCloseToLeftRestoresReferenceTab() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let aURL = directory.appendingPathComponent("LeftA.swift")
        let bURL = directory.appendingPathComponent("LeftB.swift")
        let cURL = directory.appendingPathComponent("LeftC.swift")
        try write("let a = 1\n", to: aURL)
        try write("let b = 2\n", to: bURL)
        let diskC = "let c = 3\n"
        try write(diskC, to: cURL)

        let aID = try await openSession(at: aURL)
        let bID = try await openSession(at: bURL)
        let cID = try await openSession(at: cURL)
        adapter.sessions.activate(sessionID: bID)
        try await waitUntil("B activated") {
            self.service.files.currentFileURL == bURL && self.service.files.content?.string == "let b = 2\n"
        }

        try await adapter.sessions.closeToLeft(of: cID)

        XCTAssertEqual(service.sessions.activeSessionID, cID.rawValue)
        XCTAssertEqual(service.files.currentFileURL, cURL, "左侧关闭吃掉活跃 Tab 后必须恢复参考 Tab")
        XCTAssertEqual(service.files.content?.string, diskC)
        XCTAssertEqual(service.sessions.tabs.map(\.sessionID), [cID.rawValue])
        XCTAssertFalse(service.sessions.tabs.contains { $0.sessionID == aID.rawValue })
    }

    func testCloseToRightRestoresReferenceTab() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let aURL = directory.appendingPathComponent("RightA.swift")
        let bURL = directory.appendingPathComponent("RightB.swift")
        let cURL = directory.appendingPathComponent("RightC.swift")
        let diskA = "let a = 1\n"
        try write(diskA, to: aURL)
        try write("let b = 2\n", to: bURL)
        try write("let c = 3\n", to: cURL)

        let aID = try await openSession(at: aURL)
        _ = try await openSession(at: bURL)
        let cID = try await openSession(at: cURL)

        try await adapter.sessions.closeToRight(of: aID)

        XCTAssertFalse(service.files.isFileLoadInProgress)
        XCTAssertEqual(service.sessions.activeSessionID, aID.rawValue)
        XCTAssertEqual(service.files.currentFileURL, aURL, "右侧关闭吃掉活跃 Tab 后必须恢复参考 Tab")
        XCTAssertEqual(service.files.content?.string, diskA)
        XCTAssertEqual(service.sessions.tabs.map(\.sessionID), [aID.rawValue])
        XCTAssertFalse(service.sessions.tabs.contains { $0.sessionID == cID.rawValue })
    }

    // MARK: - 晚到加载

    func testCloseDuringInFlightLoadDoesNotResurrectClosedDocument() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let aURL = directory.appendingPathComponent("RaceA.swift")
        let bURL = directory.appendingPathComponent("RaceB.swift")
        let diskA = "let a = 1\n"
        try write(diskA, to: aURL)
        try write("let b = 2\n", to: bURL)

        let aID = try await openSession(at: aURL)
        // B 的加载仍在飞行中（不让出主 actor）就关闭它：替补恢复必须胜出。
        service.sessions.open(at: bURL)
        let bSessionID = try XCTUnwrap(service.sessions.activeSession?.id)
        try await adapter.sessions.close(
            sessionID: EditorSessionID(rawValue: bSessionID),
            policy: .discardChanges
        )
        try await Task.sleep(nanoseconds: 400_000_000)

        XCTAssertEqual(service.sessions.activeSessionID, aID.rawValue)
        XCTAssertEqual(service.files.currentFileURL, aURL)
        XCTAssertEqual(service.files.content?.string, diskA, "已关闭 B 的晚到加载结果不得写回 buffer")
    }
}
#endif