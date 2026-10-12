import Foundation

extension EditorPanelSessionState {
    @MainActor
    init(session: EditorSession) {
        self = session.panelState
    }
}
