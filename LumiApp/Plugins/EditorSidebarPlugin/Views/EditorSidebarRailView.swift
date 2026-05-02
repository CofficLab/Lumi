import SwiftUI

/// 编辑器侧边栏 Rail 视图
///
/// 通过 `addRailView()` 注册，在活动栏与面板内容区之间显示。
/// 自包含所有 sidebar workspace 逻辑，通过 EnvironmentObject 访问 EditorVM 和 ProjectVM。
struct EditorSidebarRailView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var editorVM: EditorVM
    @EnvironmentObject private var projectVM: ProjectVM

    @State private var selectedTab: EditorSidebarWorkspaceTab = .explorer

    private let selectedTabStorageKey = "Split.Panel.LumiEditor.SelectedTab"

    private var service: EditorService { editorVM.service }
    private var state: EditorState { service.state }
    private var sessionStore: EditorSessionStore { service.sessionStore }
    private var workbench: EditorWorkbenchState { service.workbench }

    var body: some View {
        VStack(spacing: 0) {
            EditorSidebarTabBar(
                selectedTab: selectedTab,
                visibleTabs: visibleTabs,
                onTabSelect: selectSidebarTab,
                onDismiss: dismissSidebarTab
            )
            GlassDivider()
            EditorSidebarWorkspaceContent(
                selectedTab: selectedTab,
                state: state,
                sessionStore: sessionStore,
                workbench: workbench
            )
        }
        .frame(maxHeight: .infinity)
        .background(themeManager.activeAppTheme.sidebarBackgroundColor())
        .onAppear {
            restoreSidebarWorkspaceSelection()
        }
        .onChange(of: state.panelState.isOutlinePanelPresented) { _, isPresented in
            if isPresented {
                selectedTab = .outline
                persistSidebarWorkspaceSelection(.outline)
            } else if selectedTab == .outline {
                selectedTab = .explorer
                persistSidebarWorkspaceSelection(.explorer)
            }
        }
        .onChange(of: state.panelState.isProblemsPanelPresented) { _, isPresented in
            if isPresented {
                selectedTab = .problems
                persistSidebarWorkspaceSelection(.problems)
            } else if selectedTab == .problems {
                selectedTab = .explorer
                persistSidebarWorkspaceSelection(.explorer)
            }
        }
        .onChange(of: state.panelState.isWorkspaceSearchPresented) { _, isPresented in
            if isPresented {
                selectedTab = .searchResults
                persistSidebarWorkspaceSelection(.searchResults)
            } else if selectedTab == .searchResults {
                selectedTab = .explorer
                persistSidebarWorkspaceSelection(.explorer)
            }
        }
        .onChange(of: state.panelState.workspaceSearchResults.count) { _, count in
            guard count == 0,
                  selectedTab == .searchResults,
                  !state.panelState.isWorkspaceSearchPresented,
                  state.panelState.workspaceSearchQuery.isEmpty,
                  !state.panelState.isWorkspaceSearchLoading else { return }
            selectedTab = .explorer
            persistSidebarWorkspaceSelection(.explorer)
        }
        .onChange(of: state.panelState.isReferencePanelPresented) { _, isPresented in
            if isPresented {
                selectedTab = .references
                persistSidebarWorkspaceSelection(.references)
            } else if selectedTab == .references {
                selectedTab = .explorer
                persistSidebarWorkspaceSelection(.explorer)
            }
        }
        .onChange(of: state.panelState.isWorkspaceSymbolSearchPresented) { _, isPresented in
            if isPresented {
                selectedTab = .workspaceSymbols
                persistSidebarWorkspaceSelection(.workspaceSymbols)
            } else if selectedTab == .workspaceSymbols {
                selectedTab = .explorer
                persistSidebarWorkspaceSelection(.explorer)
            }
        }
        .onChange(of: state.callHierarchyProvider.rootItem?.name) { _, rootName in
            if rootName != nil || state.callHierarchyProvider.isLoading {
                selectedTab = .callHierarchy
                persistSidebarWorkspaceSelection(.callHierarchy)
            } else if selectedTab == .callHierarchy, !state.panelState.isCallHierarchyPresented {
                selectedTab = .explorer
                persistSidebarWorkspaceSelection(.explorer)
            }
        }
        .onChange(of: state.panelState.isCallHierarchyPresented) { _, isPresented in
            if isPresented {
                selectedTab = .callHierarchy
                persistSidebarWorkspaceSelection(.callHierarchy)
            } else if selectedTab == .callHierarchy {
                selectedTab = .explorer
                persistSidebarWorkspaceSelection(.explorer)
            }
        }
    }

    // MARK: - Visible Tabs

    private var visibleTabs: [EditorSidebarWorkspaceTab] {
        let baseTabs: [EditorSidebarWorkspaceTab] = [.explorer, .outline]
        let contextualTabs = EditorSidebarWorkspaceTab.allCases
            .filter(\.isContextual)
            .filter(shouldShowContextualTab(_:))
            .sorted { $0.priority < $1.priority }
        return baseTabs + contextualTabs
    }

    private func shouldShowContextualTab(_ tab: EditorSidebarWorkspaceTab) -> Bool {
        switch tab {
        case .explorer, .outline:
            return true
        case .problems:
            return problemCount > 0 || state.panelState.isProblemsPanelPresented
                || selectedTab == .problems
        case .searchResults:
            return state.panelState.workspaceSearchSummary != nil
                || !state.panelState.workspaceSearchResults.isEmpty
                || state.panelState.isWorkspaceSearchLoading
                || !state.panelState.workspaceSearchQuery.isEmpty
                || state.panelState.isWorkspaceSearchPresented || selectedTab == .searchResults
        case .references:
            return !state.panelState.referenceResults.isEmpty
                || state.panelState.isReferencePanelPresented || selectedTab == .references
        case .workspaceSymbols:
            return !state.workspaceSymbolProvider.symbols.isEmpty
                || state.panelState.isWorkspaceSymbolSearchPresented
                || selectedTab == .workspaceSymbols
        case .callHierarchy:
            return state.callHierarchyProvider.rootItem != nil
                || state.callHierarchyProvider.isLoading
                || state.panelState.isCallHierarchyPresented || selectedTab == .callHierarchy
        }
    }

    private var problemCount: Int {
        state.panelState.semanticProblems.count + state.panelState.problemDiagnostics.count
    }

    // MARK: - Tab Selection

    private func selectSidebarTab(_ tab: EditorSidebarWorkspaceTab) {
        persistSidebarWorkspaceSelection(tab)
        switch tab {
        case .explorer:
            state.performPanelCommand(.closeOutline)
            if selectedTab == .problems || state.panelState.activeBottomPanel == .problems {
                state.performPanelCommand(.closeProblems)
            }
            if selectedTab == .searchResults || state.panelState.activeBottomPanel == .searchResults {
                state.performPanelCommand(.closeWorkspaceSearch)
            }
            if selectedTab == .references || state.panelState.activeBottomPanel == .references {
                state.performPanelCommand(.closeReferences)
            }
            if selectedTab == .workspaceSymbols
                || state.panelState.activeBottomPanel == .workspaceSymbols
            {
                state.performPanelCommand(.closeWorkspaceSymbolSearch)
            }
            if selectedTab == .callHierarchy || state.panelState.activeBottomPanel == .callHierarchy {
                state.performPanelCommand(.closeCallHierarchy)
            }
            selectedTab = .explorer
        case .outline:
            if !state.panelState.isOutlinePanelPresented {
                state.performPanelCommand(.toggleOutline)
            } else {
                selectedTab = .outline
            }
        case .problems:
            state.presentBottomPanel(.problems)
            selectedTab = .problems
        case .searchResults:
            state.presentBottomPanel(.searchResults)
            selectedTab = .searchResults
        case .references:
            state.presentBottomPanel(.references)
            selectedTab = .references
        case .workspaceSymbols:
            state.presentBottomPanel(.workspaceSymbols)
            selectedTab = .workspaceSymbols
        case .callHierarchy:
            state.presentBottomPanel(.callHierarchy)
            selectedTab = .callHierarchy
        }
    }

    private func dismissSidebarTab(_ tab: EditorSidebarWorkspaceTab) {
        switch tab {
        case .explorer:
            break
        case .outline:
            state.performPanelCommand(.closeOutline)
        case .problems:
            state.performPanelCommand(.closeProblems)
        case .searchResults:
            state.performPanelCommand(.closeWorkspaceSearch)
        case .references:
            state.performPanelCommand(.closeReferences)
        case .workspaceSymbols:
            state.performPanelCommand(.closeWorkspaceSymbolSearch)
        case .callHierarchy:
            state.performPanelCommand(.closeCallHierarchy)
        }
        selectedTab = .explorer
        persistSidebarWorkspaceSelection(.explorer)
    }

    // MARK: - Persistence

    private func restoreSidebarWorkspaceSelection() {
        guard let rawValue = UserDefaults.standard.string(forKey: selectedTabStorageKey),
              let tab = EditorSidebarWorkspaceTab(rawValue: rawValue)
        else {
            selectSidebarTab(.explorer)
            return
        }
        if tab.isContextual {
            selectSidebarTab(.explorer)
            return
        }
        selectSidebarTab(tab)
    }

    private func persistSidebarWorkspaceSelection(_ tab: EditorSidebarWorkspaceTab) {
        let storedTab: EditorSidebarWorkspaceTab = tab.isContextual ? .explorer : tab
        UserDefaults.standard.set(storedTab.rawValue, forKey: selectedTabStorageKey)
    }
}
