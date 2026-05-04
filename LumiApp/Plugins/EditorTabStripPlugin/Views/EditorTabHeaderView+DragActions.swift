import SwiftUI
import MagicKit

// MARK: - Tab 拖拽动作

extension EditorTabHeaderView {

    func beginTabDrag(_ tab: EditorTab) {
        draggedTabSessionID = tab.sessionID
    }

    func dropDraggedTabInActiveStrip(before targetTab: EditorTab?) {
        guard let draggedTabSessionID else { return }
        defer { self.draggedTabSessionID = nil }

        if targetTab?.sessionID == draggedTabSessionID { return }

        let targetSessionID = targetTab?.sessionID
        _ = sessionStore.reorderSession(
            sessionID: draggedTabSessionID,
            before: targetSessionID
        )
    }
}
