import MagicKit
import SwiftUI

/// 编辑器 Tab Header 视图
///
/// 作为 Panel Header 提供给内核，在编辑器面板上方渲染。
/// 包含标签栏和符号栏（breadcrumb）。
struct EditorTabHeaderView: View {
    @EnvironmentObject var editorVM: EditorVM
    @EnvironmentObject var projectVM: ProjectVM
    @EnvironmentObject private var themeManager: ThemeManager

    var service: EditorService { editorVM.service }
    var sessionStore: EditorSessionStore { service.sessionStore }
    var workbench: EditorWorkbenchState { service.workbench }
    var state: EditorState { service.state }

    @State var draggedTabSessionID: EditorSession.ID?

    var body: some View {
        VStack(spacing: 0) {
            if !visibleTabs.isEmpty {
                EditorTabStripView(
                    tabs: visibleTabs,
                    activeSessionID: visibleActiveSessionID,
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

    // MARK: - 计算属性

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
}
