#if canImport(XCTest)
import XCTest
@testable import Lumi

@MainActor
final class EditorSessionControllerTests: XCTestCase {
    func testRestoreApplicationPreservesSessionStateAndBuildsBridgeState() {
        let controller = EditorSessionController()
        let session = EditorSession(
            fileURL: URL(fileURLWithPath: "/tmp/demo.md"),
            multiCursorState: MultiCursorState(
                all: [MultiCursorSelection(location: 4, length: 2)],
                primaryIndex: 0
            ),
            panelState: EditorPanelSessionState(
                mouseHoverContent: "hover",
                isReferencePanelPresented: true
            ),
            isDirty: true,
            findReplaceState: EditorFindReplaceState(
                findText: "demo",
                replaceText: "done",
                isFindPanelVisible: true
            ),
            scrollState: EditorScrollState(viewportOrigin: CGPoint(x: 0, y: 42)),
            viewState: EditorViewState(
                cursorPositions: [CursorPosition(start: .init(line: 3, column: 5), end: nil)],
                primaryCursorLine: 3,
                primaryCursorColumn: 5
            )
        )

        let application = controller.restoreApplication(
            from: session,
            fallbackCursorPositions: []
        )

        XCTAssertEqual(application.multiCursorState, session.multiCursorState)
        XCTAssertEqual(application.panelState, session.panelState)
        XCTAssertEqual(application.scrollState, session.scrollState)
        XCTAssertEqual(application.resolvedInteraction.bridgeState?.viewState, session.viewState)
        XCTAssertEqual(
            application.resolvedInteraction.bridgeState?.findReplaceState,
            session.findReplaceState
        )
    }

    func testApplyBridgeStateMutatesSourceEditorStateAndCursorMirror() {
        let controller = EditorSessionController()
        var sourceEditorState = SourceEditorState()
        var cursorLine = 1
        var cursorColumn = 1
        let expectedFindReplaceState = EditorFindReplaceState(
            findText: "needle",
            replaceText: "thread",
            isFindPanelVisible: true
        )
        let bridgeState = EditorBridgeState(
            viewState: EditorViewState(
                cursorPositions: [CursorPosition(start: .init(line: 8, column: 13), end: nil)],
                primaryCursorLine: 8,
                primaryCursorColumn: 13
            ),
            findReplaceState: expectedFindReplaceState
        )

        let appliedFindReplaceState = controller.applyBridgeState(
            bridgeState,
            to: &sourceEditorState,
            cursorLine: &cursorLine,
            cursorColumn: &cursorColumn
        )

        XCTAssertEqual(sourceEditorState.cursorPositions, bridgeState.viewState.cursorPositions)
        XCTAssertEqual(cursorLine, 8)
        XCTAssertEqual(cursorColumn, 13)
        XCTAssertEqual(appliedFindReplaceState, expectedFindReplaceState)
    }

    func testSyncActiveSessionStateAppliesSnapshotAndCallsObserver() {
        let controller = EditorSessionController()
        let activeSession = EditorSession()
        let expectedBridgeState = EditorBridgeState(
            viewState: EditorViewState(
                cursorPositions: [CursorPosition(start: .init(line: 2, column: 7), end: nil)],
                primaryCursorLine: 2,
                primaryCursorColumn: 7
            ),
            findReplaceState: EditorFindReplaceState(
                findText: "alpha",
                replaceText: "beta",
                isFindPanelVisible: true
            )
        )
        let expectedPanelState = EditorPanelSessionState(
            mouseHoverContent: "hover",
            isOpenEditorsPanelPresented: true
        )
        var observedSessionID: UUID?

        controller.syncActiveSessionState(
            activeSession: activeSession,
            fileURL: URL(fileURLWithPath: "/tmp/file.swift"),
            multiCursorState: MultiCursorState(
                all: [MultiCursorSelection(location: 1, length: 0)],
                primaryIndex: 0
            ),
            panelState: expectedPanelState,
            isDirty: true,
            bridgeState: expectedBridgeState,
            scrollState: EditorScrollState(viewportOrigin: CGPoint(x: 0, y: 20)),
            onChanged: { session in
                observedSessionID = session.id
            }
        )

        XCTAssertEqual(activeSession.fileURL?.path, "/tmp/file.swift")
        XCTAssertEqual(activeSession.multiCursorState.primaryIndex, 0)
        XCTAssertEqual(activeSession.panelState, expectedPanelState)
        XCTAssertTrue(activeSession.isDirty)
        XCTAssertEqual(activeSession.findReplaceState, expectedBridgeState.findReplaceState)
        XCTAssertEqual(activeSession.viewState, expectedBridgeState.viewState)
        XCTAssertEqual(activeSession.scrollState.viewportOrigin.y, 20)
        XCTAssertEqual(observedSessionID, activeSession.id)
    }
}
#endif
