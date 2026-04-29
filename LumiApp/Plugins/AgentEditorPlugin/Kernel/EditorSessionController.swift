import Foundation
import AppKit
import CodeEditSourceEditor
import CodeEditTextView

@MainActor
final class EditorSessionController {
    struct SessionRestoreApplication {
        let multiCursorState: MultiCursorState
        let panelState: EditorPanelSessionState
        let resolvedInteraction: ResolvedEditorInteractionUpdate
        let scrollState: EditorScrollState
    }

    func restoreApplication(
        from session: EditorSession,
        fallbackCursorPositions: [CursorPosition]
    ) -> SessionRestoreApplication {
        let restore = EditorSessionRestoreController.restoreResult(
            from: session,
            fallbackCursorPositions: fallbackCursorPositions
        )

        return SessionRestoreApplication(
            multiCursorState: session.multiCursorState,
            panelState: session.panelState,
            resolvedInteraction: EditorInteractionUpdateController.resolve(
                .sessionRestore(restore),
                currentViewState: session.viewState
            ),
            scrollState: restore.scrollState
        )
    }

    func resolveInteractionUpdate(
        _ update: EditorInteractionUpdate,
        currentBridgeState: EditorBridgeState
    ) -> ResolvedEditorInteractionUpdate {
        EditorInteractionUpdateController.resolve(
            update,
            currentViewState: currentBridgeState.viewState
        )
    }

    func currentBridgeState(
        from editorState: SourceEditorState,
        cursorLine: Int,
        cursorColumn: Int,
        currentFindReplaceState: EditorFindReplaceState
    ) -> EditorBridgeState {
        EditorBridgeStateController.state(
            from: editorState,
            cursorLine: cursorLine,
            cursorColumn: cursorColumn,
            currentFindReplaceState: currentFindReplaceState
        )
    }

    func applyBridgeState(
        _ state: EditorBridgeState,
        to editorState: inout SourceEditorState,
        cursorLine: inout Int,
        cursorColumn: inout Int
    ) -> EditorFindReplaceState? {
        editorState.cursorPositions = state.viewState.cursorPositions
        cursorLine = state.viewState.primaryCursorLine
        cursorColumn = state.viewState.primaryCursorColumn
        return state.findReplaceState
    }

    func syncActiveSessionState(
        activeSession: EditorSession,
        fileURL: URL?,
        multiCursorState: MultiCursorState,
        panelState: EditorPanelSessionState,
        isDirty: Bool,
        bridgeState: EditorBridgeState,
        scrollState: EditorScrollState,
        onChanged: ((EditorSession) -> Void)?
    ) {
        let snapshot = EditorSessionSnapshotBuilder.snapshot(
            preserving: activeSession.id,
            fileURL: fileURL,
            multiCursorState: multiCursorState,
            panelState: panelState,
            isDirty: isDirty,
            bridgeState: bridgeState,
            scrollState: scrollState
        )
        activeSession.applySnapshot(from: snapshot)
        onChanged?(activeSession)
    }

    func withSessionSyncSuspended(
        _ isSessionSyncSuspended: inout Bool,
        operation: () -> Void
    ) {
        let previousValue = isSessionSyncSuspended
        isSessionSyncSuspended = true
        operation()
        isSessionSyncSuspended = previousValue
    }

    func restoreScrollState(
        _ state: EditorScrollState,
        in textView: TextView?
    ) {
        guard let textView,
              let scrollView = textView.enclosingScrollView else { return }
        let clipView = scrollView.contentView
        clipView.scroll(to: state.viewportOrigin)
        scrollView.reflectScrolledClipView(clipView)
    }
}
