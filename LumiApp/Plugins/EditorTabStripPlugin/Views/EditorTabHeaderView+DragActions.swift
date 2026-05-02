import MagicKit
import SwiftUI

// MARK: - Tab 拖拽动作

extension EditorTabHeaderView {

    func beginTabDrag(_ tab: EditorTab) {
        draggedTabSessionID = tab.sessionID
    }

    func dropDraggedTabInActiveStrip(before targetTab: EditorTab?) {
        guard let activeGroup = workbench.activeGroup else {
            draggedTabSessionID = nil
            return
        }
        guard let draggedTabSessionID else { return }
        defer { self.draggedTabSessionID = nil }

        if targetTab?.sessionID == draggedTabSessionID { return }

        let sourceGroupID = workbench.groupContainingSession(sessionID: draggedTabSessionID)?.id
        let targetSessionID = targetTab?.sessionID

        if sourceGroupID == activeGroup.id {
            guard workbench.reorderSession(
                sessionID: draggedTabSessionID,
                in: activeGroup.id,
                before: targetSessionID
            ) else { return }
            _ = sessionStore.reorderSession(
                sessionID: draggedTabSessionID,
                before: targetSessionID
            )
            return
        }

        // Cross-group move
        guard workbench.moveSession(
            sessionID: draggedTabSessionID,
            toGroupID: activeGroup.id,
            before: targetSessionID
        ) else { return }
        workbench.activateGroup(activeGroup.id)

        if let targetSessionID {
            _ = sessionStore.reorderSession(sessionID: draggedTabSessionID, before: targetSessionID)
        } else {
            _ = sessionStore.reorderSession(sessionID: draggedTabSessionID, before: nil)
        }
    }
}
