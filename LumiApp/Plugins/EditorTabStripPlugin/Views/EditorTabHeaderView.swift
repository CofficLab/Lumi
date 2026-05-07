import MagicKit
import SwiftUI

/// 编辑器 Tab Header 视图
///
/// 作为 Panel Header 提供给内核，在编辑器面板上方渲染。
/// 包含标签栏和符号栏（breadcrumb）。
struct EditorTabHeaderView: View {

    // MARK: - 属性

    @EnvironmentObject var editorVM: EditorVM
    @EnvironmentObject var projectVM: ProjectVM
    @EnvironmentObject private var themeVM: ThemeVM

    @State var draggedTabSessionID: EditorSession.ID?

    // MARK: - 公开方法

    var body: some View {
        VStack(spacing: 0) {
            if !visibleTabs.isEmpty {
                tabStripBar
            }

            if !activeDocumentSymbolTrail.isEmpty {
                EditorStickySymbolBarView(
                    state: state,
                    symbols: activeDocumentSymbolTrail
                )
            }
        }
        .background(
            theme.workspaceBackgroundColor()
                .ignoresSafeArea()
        )
        .zIndex(1)
    }

    // MARK: - 私有方法

    private func beginTabDrag(_ tab: EditorTab) {
        draggedTabSessionID = tab.sessionID
    }

    private func dropDraggedTabInActiveStrip(before targetTab: EditorTab?) {
        guard let draggedTabSessionID else { return }
        defer { self.draggedTabSessionID = nil }

        if targetTab?.sessionID == draggedTabSessionID { return }

        let targetSessionID = targetTab?.sessionID
        _ = sessionStore.reorderSession(
            sessionID: draggedTabSessionID,
            before: targetSessionID
        )
    }

    // MARK: - 计算属性

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

    private var tabStripBar: some View {
        HStack(spacing: 4) {
            ScrollView(.horizontal, showsIndicators: false) {
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
                .onDrop(of: [.plainText], isTargeted: nil) { _ in
                    dropDraggedTabInActiveStrip(before: nil)
                    return true
                }
            }
        }
        .background(theme.workspaceTertiaryTextColor().opacity(0.06))
    }
}
