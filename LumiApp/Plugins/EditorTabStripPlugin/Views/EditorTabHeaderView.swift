import MagicKit
import SwiftUI

/// 编辑器 Tab Header 视图
///
/// 作为 Panel Header 提供给内核，在编辑器面板上方渲染。
/// 包含标签栏和符号栏（breadcrumb）。
struct EditorTabHeaderView: View {
    @EnvironmentObject private var editorVM: EditorVM
    @EnvironmentObject private var projectVM: ProjectVM
    @EnvironmentObject private var themeManager: ThemeManager

    private var service: EditorService { editorVM.service }
    private var sessionStore: EditorSessionStore { service.sessionStore }
    private var workbench: EditorWorkbenchState { service.workbench }
    private var state: EditorState { service.state }

    @State private var draggedTabSessionID: EditorSession.ID?

    var body: some View {
        VStack(spacing: 0) {
            if !visibleTabs.isEmpty {
                EditorTabStripView(
                    tabs: visibleTabs,
                    activeSessionID: visibleActiveSessionID,
                    onSelect: activateSession,
                    onClose: closeSession,
                    onCloseOthers: closeOtherSessions,
                    onTogglePinned: togglePinned,
                    onStartDrag: beginTabDrag,
                    onDropBefore: dropDraggedTabInActiveStrip
                )
            }

            if !activeDocumentSymbolTrail.isEmpty {
                EditorStickySymbolBarView(
                    state: state,
                    symbols: activeDocumentSymbolTrail
                )
            }
        }
        .background(
            themeManager.activeAppTheme.workspaceBackgroundColor()
                .ignoresSafeArea()
        )
        .zIndex(1)
    }

    // MARK: - Tab Data

    private var visibleTabs: [EditorTab] {
        if let activeGroup = workbench.activeGroup, !activeGroup.tabs.isEmpty {
            return activeGroup.tabs
        }
        return sessionStore.tabs
    }

    private var visibleActiveSessionID: EditorSession.ID? {
        workbench.activeGroup?.activeSessionID ?? sessionStore.activeSessionID
    }

    private var activeDocumentSymbolTrail: [EditorDocumentSymbolItem] {
        state.documentSymbolProvider.activeItems(for: state.cursorLine)
    }

    // MARK: - Actions

    private func activateSession(_ tab: EditorTab) {
        _ = sessionStore.activate(sessionID: tab.sessionID)
        _ = workbench.activate(sessionID: tab.sessionID)
        if let fileURL = tab.fileURL {
            projectVM.selectFile(at: fileURL)
        }
    }

    private func closeSession(_ tab: EditorTab) {
        guard let session = sessionStore.session(for: tab.sessionID) else { return }
        let wasActive = session.id == sessionStore.activeSessionID
        let nextGroupSession = workbench.close(sessionID: session.id)
        if wasActive, state.hasUnsavedChanges {
            state.saveNow()
        }

        let nextSession = sessionStore.close(sessionID: session.id)
        guard wasActive else {
            return
        }

        if let nextFileURL = nextSession?.fileURL {
            projectVM.selectFile(at: nextFileURL)
        } else {
            projectVM.clearFileSelection()
        }
    }

    private func closeOtherSessions(_ tab: EditorTab) {
        guard let session = sessionStore.session(for: tab.sessionID) else { return }
        if state.currentFileURL != session.fileURL, state.hasUnsavedChanges {
            state.saveNow()
        }

        let _ = workbench.closeOthers(keeping: session.id)
        let keptSession = sessionStore.closeOthers(keeping: session.id)
        if let fileURL = keptSession?.fileURL {
            projectVM.selectFile(at: fileURL)
        } else {
            projectVM.clearFileSelection()
        }
    }

    private func togglePinned(_ tab: EditorTab) {
        sessionStore.togglePinned(sessionID: tab.sessionID)
        workbench.groupContainingSession(sessionID: tab.sessionID)?.togglePinned(sessionID: tab.sessionID)
    }

    private func beginTabDrag(_ tab: EditorTab) {
        draggedTabSessionID = tab.sessionID
    }

    private func dropDraggedTabInActiveStrip(before targetTab: EditorTab?) {
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
