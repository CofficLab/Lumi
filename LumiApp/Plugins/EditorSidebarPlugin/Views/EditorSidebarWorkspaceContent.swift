import SwiftUI

// MARK: - Content

/// 侧边栏 workspace 内容区
///
/// 根据 selectedTab 切换显示不同的面板视图。
struct EditorSidebarWorkspaceContent: View {
    let selectedTab: EditorSidebarWorkspaceTab
    @ObservedObject var state: EditorState
    let sessionStore: EditorSessionStore
    let workbench: EditorWorkbenchState

    var body: some View {
        switch selectedTab {
        case .explorer:
            EditorFileTreeView()
        case .outline:
            if let provider = state.documentSymbolProvider as? DocumentSymbolProvider {
                EditorOutlinePanelView(
                    state: state,
                    provider: provider,
                    showsHeader: false,
                    showsResizeHandle: false
                )
            } else {
                Text("Outline not available")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .problems:
            EditorProblemsPanelView(state: state, showsHeader: false)
        case .searchResults:
            EditorWorkspaceSearchPanelView(state: state, showsToolbar: true)
        case .references:
            EditorReferencesWorkspacePanelView(state: state, showsHeader: false)
        case .workspaceSymbols:
            EditorWorkspaceSymbolsPanelView(state: state, showsHeader: false)
        case .callHierarchy:
            EditorCallHierarchyPanelView(state: state, showsHeader: false)
        }
    }
}
