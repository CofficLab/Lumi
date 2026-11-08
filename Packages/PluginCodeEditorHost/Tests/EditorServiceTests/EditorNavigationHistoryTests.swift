import XCTest
@testable import EditorService

/// 回归 #982：同一 Session 会在导航历史里留下多个非相邻条目，关闭标签时必须
/// 把它们全部清掉，否则“后退”会选中已关闭的 Session。
@MainActor
final class EditorNavigationHistoryTests: XCTestCase {

    private func makeSession(_ name: String) -> EditorSession {
        EditorSession(fileURL: URL(fileURLWithPath: "/tmp/\(name).swift"))
    }

    func testRemoveDropsEveryEntryForClosedSession() {
        var history = EditorNavigationHistory()
        let a = makeSession("A")
        let b = makeSession("B")
        let c = makeSession("C")

        // A → B → A → C：A 在历史中出现两次且不相邻。
        history.recordVisit(a)
        history.recordVisit(b)
        history.recordVisit(a)
        history.recordVisit(c)
        XCTAssertEqual(history.sessionIDs, [a.id, b.id, a.id, c.id])
        XCTAssertEqual(history.currentSessionID, c.id)

        history.remove(a.id)

        XCTAssertEqual(history.sessionIDs, [b.id, c.id])
        XCTAssertEqual(history.currentSessionID, c.id)
        XCTAssertTrue(history.canGoBack)
        XCTAssertEqual(history.goBack()?.sessionID, b.id)
        XCTAssertFalse(history.sessionIDs.contains(a.id))
    }

    func testRemoveFallsBackToNearestEntryWhenCurrentSessionClosed() {
        var history = EditorNavigationHistory()
        let a = makeSession("A")
        let b = makeSession("B")
        let c = makeSession("C")

        history.recordVisit(a)
        history.recordVisit(b)
        history.recordVisit(a)
        history.recordVisit(c)
        XCTAssertEqual(history.goBack()?.sessionID, a.id)

        history.remove(a.id)

        XCTAssertEqual(history.sessionIDs, [b.id, c.id])
        XCTAssertEqual(history.currentSessionID, c.id)
    }
}
