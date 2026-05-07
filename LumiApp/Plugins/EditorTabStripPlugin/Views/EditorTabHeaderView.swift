import MagicKit
import SwiftUI

/// 编辑器 Tab Header 视图
struct EditorTabHeaderView: View {
    @EnvironmentObject var editorVM: EditorVM
    @EnvironmentObject private var themeVM: ThemeVM
    @State private var draggedTabSessionID: EditorSession.ID?

    var body: some View {
        if !visibleTabs.isEmpty {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(visibleTabs) { tab in
                        EditorTabItemView(
                            tab: tab,
                            isActive: tab.sessionID == visibleActiveSessionID,
                            theme: theme,
                            onStartDrag: beginTabDrag,
                            onDropBefore: dropDraggedTabInActiveStrip
                        )
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.workspaceTertiaryTextColor().opacity(0.06))
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(theme.workspaceTertiaryTextColor().opacity(0.08))
                        .frame(height: 1)
                }
                .onDrop(of: [.plainText], isTargeted: nil) { _ in
                    dropDraggedTabInActiveStrip(before: nil)
                    return true
                }

                if !activeDocumentSymbolTrail.isEmpty {
                    EditorStickySymbolBarView(
                        state: state,
                        symbols: activeDocumentSymbolTrail
                    )
                }
            }
            .background(theme.workspaceBackgroundColor())
            .zIndex(1)
        }
    }

    var service: EditorService { editorVM.service }
    var sessionStore: EditorSessionStore { service.sessionStore }
    var state: EditorState { service.state }

    private var theme: any SuperTheme {
        themeVM.activeAppTheme
    }

    private var visibleTabs: [EditorTab] {
        sessionStore.tabs
    }

    private var visibleActiveSessionID: EditorSession.ID? {
        sessionStore.activeSessionID
    }

    private var activeDocumentSymbolTrail: [EditorDocumentSymbolItem] {
        state.documentSymbolProvider.activeItems(for: state.cursorLine)
    }

    private func beginTabDrag(_ tab: EditorTab) {
        draggedTabSessionID = tab.sessionID
    }

    private func dropDraggedTabInActiveStrip(before targetTab: EditorTab?) {
        guard let draggedTabSessionID else { return }
        defer { self.draggedTabSessionID = nil }

        if targetTab?.sessionID == draggedTabSessionID { return }

        _ = sessionStore.reorderSession(
            sessionID: draggedTabSessionID,
            before: targetTab?.sessionID
        )
    }
}
