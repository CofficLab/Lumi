#if canImport(XCTest)
import XCTest
@testable import Lumi

@MainActor
final class EditorSessionStoreTests: XCTestCase {
    func testOpenOrActivateReusesExistingSessionForSameFile() {
        let store = EditorSessionStore()
        let fileURL = URL(fileURLWithPath: "/tmp/demo.swift")

        let first = store.openOrActivate(fileURL: fileURL)
        let second = store.openOrActivate(fileURL: fileURL)

        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertEqual(store.tabs.count, 1)
        XCTAssertEqual(first?.id, second?.id)
        XCTAssertEqual(store.activeSession?.fileURL, fileURL)
    }

    func testSyncActiveSessionCopiesSnapshotIntoStoredSession() {
        let store = EditorSessionStore()
        let fileURL = URL(fileURLWithPath: "/tmp/demo.swift")
        let snapshot = EditorSession(
            fileURL: fileURL,
            panelState: .init(mouseHoverContent: "hover"),
            isDirty: true,
            viewState: .init(primaryCursorLine: 9, primaryCursorColumn: 12, cursorPositions: [])
        )

        store.syncActiveSession(from: snapshot)

        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertEqual(store.activeSession?.fileURL, fileURL)
        XCTAssertEqual(store.activeSession?.viewState.primaryCursorLine, 9)
        XCTAssertEqual(store.activeSession?.viewState.primaryCursorColumn, 12)
        XCTAssertEqual(store.activeSession?.mouseHoverContent, "hover")
        XCTAssertEqual(store.activeSession?.isDirty, true)
        XCTAssertEqual(store.tabs.first?.isDirty, true)
    }

    func testCloseAllClearsSessionsAndActiveSelection() {
        let store = EditorSessionStore()
        _ = store.openOrActivate(fileURL: URL(fileURLWithPath: "/tmp/demo.swift"))

        store.closeAll()

        XCTAssertTrue(store.sessions.isEmpty)
        XCTAssertTrue(store.tabs.isEmpty)
        XCTAssertNil(store.activeSession)
    }

    func testCloseActiveSessionActivatesNeighbor() {
        let store = EditorSessionStore()
        let first = store.openOrActivate(fileURL: URL(fileURLWithPath: "/tmp/a.swift"))
        let second = store.openOrActivate(fileURL: URL(fileURLWithPath: "/tmp/b.swift"))

        let next = store.close(sessionID: second!.id)

        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertEqual(store.tabs.count, 1)
        XCTAssertEqual(next?.id, first?.id)
        XCTAssertEqual(store.activeSession?.id, first?.id)
    }

    func testCloseOthersKeepsOnlyRequestedSession() {
        let store = EditorSessionStore()
        _ = store.openOrActivate(fileURL: URL(fileURLWithPath: "/tmp/a.swift"))
        let second = store.openOrActivate(fileURL: URL(fileURLWithPath: "/tmp/b.swift"))
        _ = store.openOrActivate(fileURL: URL(fileURLWithPath: "/tmp/c.swift"))

        let kept = store.closeOthers(keeping: second!.id)

        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertEqual(store.tabs.count, 1)
        XCTAssertEqual(store.activeSession?.id, second?.id)
        XCTAssertEqual(kept?.id, second?.id)
    }

    func testGoBackAndForwardFollowActivationHistory() {
        let store = EditorSessionStore()
        let first = store.openOrActivate(fileURL: URL(fileURLWithPath: "/tmp/a.swift"))
        let second = store.openOrActivate(fileURL: URL(fileURLWithPath: "/tmp/b.swift"))
        let third = store.openOrActivate(fileURL: URL(fileURLWithPath: "/tmp/c.swift"))

        XCTAssertEqual(store.activeSession?.id, third?.id)

        let previous = store.goBack()
        let current = store.goBack()
        let forward = store.goForward()

        XCTAssertEqual(previous?.id, second?.id)
        XCTAssertEqual(current?.id, first?.id)
        XCTAssertEqual(forward?.id, second?.id)
    }

    func testHistoryNavigationDoesNotBreakForwardAfterReopeningVisitedSession() {
        let store = EditorSessionStore()
        _ = store.openOrActivate(fileURL: URL(fileURLWithPath: "/tmp/a.swift"))
        let second = store.openOrActivate(fileURL: URL(fileURLWithPath: "/tmp/b.swift"))
        let third = store.openOrActivate(fileURL: URL(fileURLWithPath: "/tmp/c.swift"))

        let previous = store.goBack()
        _ = store.openOrActivate(fileURL: previous?.fileURL)
        let forward = store.goForward()

        XCTAssertEqual(previous?.id, second?.id)
        XCTAssertEqual(forward?.id, third?.id)
    }

    func testTogglePinnedMovesTabAheadOfUnpinnedTabs() {
        let store = EditorSessionStore()
        let first = store.openOrActivate(fileURL: URL(fileURLWithPath: "/tmp/Beta.swift"))
        let second = store.openOrActivate(fileURL: URL(fileURLWithPath: "/tmp/Alpha.swift"))

        store.togglePinned(sessionID: first!.id)

        XCTAssertEqual(store.tabs.first?.sessionID, first?.id)
        XCTAssertEqual(store.tabs.first?.isPinned, true)
        XCTAssertEqual(store.tabs.last?.sessionID, second?.id)
    }

    func testUnsplitActiveLeafCollapsesNearestSplitAncestor() {
        let workbench = EditorWorkbenchState()
        let fileURL = URL(fileURLWithPath: "/tmp/demo.swift")

        _ = workbench.openOrActivate(fileURL: fileURL)
        let originalRootID = workbench.rootGroup.id

        workbench.splitActiveGroup(.horizontal)

        XCTAssertEqual(workbench.leafGroups.count, 2)
        XCTAssertNotEqual(workbench.activeGroupID, originalRootID)

        workbench.unsplitActiveGroup()

        XCTAssertEqual(workbench.leafGroups.count, 1)
        XCTAssertEqual(workbench.activeGroupID, originalRootID)
        XCTAssertEqual(workbench.rootGroup.id, originalRootID)
        XCTAssertTrue(workbench.rootGroup.isLeaf)
    }
}
#endif
