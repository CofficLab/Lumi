#if canImport(XCTest)
import Foundation
import XCTest
@testable import EditorService

@MainActor
final class EditorContextTabStripTests: XCTestCase {
    private func makeContext() -> (context: EditorContext, service: EditorService) {
        let service = EditorService(editorExtensionRegistry: EditorExtensionRegistry())
        return (EditorContext(service: service), service)
    }

    private var tempDir: URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("TabStripTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeURL(_ name: String) -> URL {
        let url = tempDir.appendingPathComponent(name)
        FileManager.default.createFile(atPath: url.path, contents: Data("content\n".utf8))
        return url
    }

    /// 打开 3 个标签（a、b、c），返回各 session id。
    private func openThreeTabs(_ service: EditorService) -> (a: UUID, b: UUID, c: UUID) {
        let a = service.sessions.openFile(at: makeURL("TabStrip-a.swift"))!.id
        let b = service.sessions.openFile(at: makeURL("TabStrip-b.swift"))!.id
        let c = service.sessions.openFile(at: makeURL("TabStrip-c.swift"))!.id
        return (a, b, c)
    }

    func testCurrentTabsReflectSessionOrderAndActiveSession() {
        let (context, service) = makeContext()
        let ids = openThreeTabs(service)

        XCTAssertEqual(context.currentTabs.map(\.sessionID), [ids.a, ids.b, ids.c])
        XCTAssertEqual(context.currentActiveSessionID, ids.c)
    }

    func testCloseTabsToLeftKeepsRightSideTabs() {
        let (context, service) = makeContext()
        let ids = openThreeTabs(service)
        // 激活最左侧标签后关闭其左侧（空操作），再针对 c 关闭左侧
        context.activateSession(id: ids.a)
        context.closeTabsToLeft(of: ids.a)
        XCTAssertEqual(context.currentTabs.count, 3)

        context.closeTabsToLeft(of: ids.c)
        XCTAssertEqual(context.currentTabs.map(\.sessionID), [ids.c])
        XCTAssertEqual(context.currentActiveSessionID, ids.c)
    }

    func testCloseTabsToRightKeepsLeftSideTabs() {
        let (context, service) = makeContext()
        let ids = openThreeTabs(service)
        context.activateSession(id: ids.a)

        context.closeTabsToRight(of: ids.a)
        XCTAssertEqual(context.currentTabs.map(\.sessionID), [ids.a])
        XCTAssertEqual(context.currentActiveSessionID, ids.a)
    }

    func testActivateAndCloseSessionViaContext() {
        let (context, service) = makeContext()
        let ids = openThreeTabs(service)

        context.activateSession(id: ids.a)
        XCTAssertEqual(context.currentActiveSessionID, ids.a)

        let next = context.closeSession(id: ids.a)
        XCTAssertEqual(next, ids.b)
        XCTAssertEqual(context.currentTabs.map(\.sessionID), [ids.b, ids.c])
        XCTAssertEqual(context.currentActiveSessionID, ids.b)
    }

    func testOpenFileSessionInBackgroundDoesNotStealFocus() {
        let (context, service) = makeContext()
        let ids = openThreeTabs(service)

        _ = service.sessions.openFileSessionInBackground(at: makeURL("TabStrip-bg.swift"))
        XCTAssertEqual(context.currentActiveSessionID, ids.c)
        XCTAssertEqual(context.currentTabs.count, 4)
    }

    func testTogglePinnedMarksSessionPinned() {
        let (context, service) = makeContext()
        let ids = openThreeTabs(service)

        context.togglePinned(sessionID: ids.a)
        let pinnedTabs = context.currentTabs.filter(\.isPinned)
        XCTAssertTrue(pinnedTabs.contains { $0.sessionID == ids.a })
    }
}
#endif
