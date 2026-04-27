import Foundation
import AppKit
import LanguageServerProtocol

@MainActor
enum EditorSessionSnapshotBuilder {
    static func snapshot(
        preserving sessionID: UUID,
        fileURL: URL?,
        multiCursorState: MultiCursorState,
        panelState: EditorPanelSessionState,
        isDirty: Bool,
        findReplaceState: EditorFindReplaceState,
        scrollState: EditorScrollState,
        viewState: EditorViewState
    ) -> EditorSession {
        EditorSession(
            id: sessionID,
            fileURL: fileURL,
            multiCursorState: multiCursorState,
            panelState: panelState,
            isDirty: isDirty,
            findReplaceState: findReplaceState,
            scrollState: scrollState,
            viewState: viewState
        )
    }

    static func snapshot(
        preserving sessionID: UUID,
        fileURL: URL?,
        multiCursorState: MultiCursorState,
        panelState: EditorPanelSessionState,
        isDirty: Bool,
        bridgeState: EditorBridgeState,
        scrollState: EditorScrollState
    ) -> EditorSession {
        snapshot(
            preserving: sessionID,
            fileURL: fileURL,
            multiCursorState: multiCursorState,
            panelState: panelState,
            isDirty: isDirty,
            findReplaceState: bridgeState.findReplaceState ?? EditorFindReplaceState(),
            scrollState: scrollState,
            viewState: bridgeState.viewState
        )
    }
}
