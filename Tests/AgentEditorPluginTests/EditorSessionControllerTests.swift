#if canImport(XCTest)
import XCTest
import CodeEditSourceEditor
@testable import Lumi

@MainActor
final class EditorSessionControllerTests: XCTestCase {
    func testRestoreApplicationPreservesSessionStateAndBuildsBridgeState() {
        let controller = EditorSessionController()
        let session = EditorSession(
            fileURL: URL(fileURLWithPath: "/tmp/demo.md"),
            multiCursorState: MultiCursorState(
                primary: MultiCursorSelection(location: 4, length: 2)
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
                primaryCursorLine: 3,
                primaryCursorColumn: 5,
                cursorPositions: [CursorPosition(start: .init(line: 3, column: 5), end: nil)]
            )
        )

        let application = controller.restoreApplication(
            from: session,
            fallbackCursorPositions: []
        )

        XCTAssertEqual(application.multiCursorState.primary, session.multiCursorState.primary)
        XCTAssertEqual(application.multiCursorState.secondary, session.multiCursorState.secondary)
        XCTAssertEqual(application.panelState, session.panelState)
        XCTAssertEqual(application.scrollState, session.scrollState)
        XCTAssertEqual(
            application.resolvedInteraction.bridgeState?.viewState.primaryCursorLine,
            session.viewState.primaryCursorLine
        )
        XCTAssertEqual(
            application.resolvedInteraction.bridgeState?.viewState.primaryCursorColumn,
            session.viewState.primaryCursorColumn
        )
        XCTAssertEqual(
            application.resolvedInteraction.bridgeState?.viewState.cursorPositions,
            session.viewState.cursorPositions
        )
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
                primaryCursorLine: 8,
                primaryCursorColumn: 13,
                cursorPositions: [CursorPosition(start: .init(line: 8, column: 13), end: nil)]
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
                primaryCursorLine: 2,
                primaryCursorColumn: 7,
                cursorPositions: [CursorPosition(start: .init(line: 2, column: 7), end: nil)]
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
                primary: MultiCursorSelection(location: 1, length: 0)
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
        XCTAssertEqual(activeSession.multiCursorState.primary, MultiCursorSelection(location: 1, length: 0))
        XCTAssertEqual(activeSession.panelState, expectedPanelState)
        XCTAssertTrue(activeSession.isDirty)
        XCTAssertEqual(activeSession.findReplaceState, expectedBridgeState.findReplaceState)
        XCTAssertEqual(activeSession.viewState.primaryCursorLine, expectedBridgeState.viewState.primaryCursorLine)
        XCTAssertEqual(activeSession.viewState.primaryCursorColumn, expectedBridgeState.viewState.primaryCursorColumn)
        XCTAssertEqual(activeSession.viewState.cursorPositions, expectedBridgeState.viewState.cursorPositions)
        XCTAssertEqual(activeSession.scrollState.viewportOrigin.y, 20)
        XCTAssertEqual(observedSessionID, activeSession.id)
    }
}
#endif
