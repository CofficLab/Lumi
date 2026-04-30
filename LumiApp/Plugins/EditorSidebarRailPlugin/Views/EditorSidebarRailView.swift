import SwiftUI

// MARK: - Tab

enum EditorSidebarWorkspaceTab: String, CaseIterable, Identifiable {
    case explorer
    case openEditors
    case outline
    case problems
    case searchResults
    case references
    case workspaceSymbols
    case callHierarchy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .explorer:
            "Explorer"
        case .openEditors:
            "Open Editors"
        case .outline:
            "Outline"
        case .problems:
            "Problems"
        case .searchResults:
            "Search"
        case .references:
            "References"
        case .workspaceSymbols:
            "Symbols"
        case .callHierarchy:
            "Calls"
        }
    }

    var systemImage: String {
        switch self {
        case .explorer:
            "folder"
        case .openEditors:
            "sidebar.left"
        case .outline:
            "list.bullet.indent"
        case .problems:
            "exclamationmark.bubble"
        case .searchResults:
            "magnifyingglass"
        case .references:
            "arrow.triangle.branch"
        case .workspaceSymbols:
            "text.magnifyingglass"
        case .callHierarchy:
            "point.3.connected.trianglepath.dotted"
        }
    }

    var isContextual: Bool {
        switch self {
        case .explorer, .openEditors, .outline:
            return false
        case .problems, .searchResults, .references, .workspaceSymbols, .callHierarchy:
            return true
        }
    }

    var priority: Int {
        switch self {
        case .explorer:
            return 0
        case .openEditors:
            return 1
        case .outline:
            return 2
        case .problems:
            return 10
        case .searchResults:
            return 11
        case .references:
            return 12
        case .workspaceSymbols:
            return 13
        case .callHierarchy:
            return 14
        }
    }
}

// MARK: - Rail View

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

    private var state: EditorState { editorVM.state }
    private var sessionStore: EditorSessionStore { editorVM.sessionStore }
    private var workbench: EditorWorkbenchState { editorVM.workbench }

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            GlassDivider()
            EditorSidebarWorkspaceContent(
                selectedTab: selectedTab,
                state: state,
                sessionStore: sessionStore,
                workbench: workbench,
                openEditors: openEditorItems,
                onSelectOpenEditor: activateOpenEditor,
                onCloseOpenEditor: closeOpenEditorItem,
                onCloseOtherOpenEditors: closeOtherOpenEditorItems,
                onTogglePinnedOpenEditor: togglePinnedOpenEditorItem,
                onSelectTab: selectSidebarTab,
                onDismissTab: dismissSidebarTab
            )
        }
        .frame(maxHeight: .infinity)
        .background(themeManager.activeAppTheme.sidebarBackgroundColor())
        .onAppear {
            restoreSidebarWorkspaceSelection()
        }
        .onChange(of: state.panelState.isOpenEditorsPanelPresented) { _, isPresented in
            if isPresented {
                selectedTab = .openEditors
                persistSidebarWorkspaceSelection(.openEditors)
            } else if !state.panelState.isOutlinePanelPresented, selectedTab == .openEditors {
                selectedTab = .explorer
                persistSidebarWorkspaceSelection(.explorer)
            }
        }
        .onChange(of: state.panelState.isOutlinePanelPresented) { _, isPresented in
            if isPresented {
                selectedTab = .outline
                persistSidebarWorkspaceSelection(.outline)
            } else if !state.panelState.isOpenEditorsPanelPresented, selectedTab == .outline {
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

    // MARK: - Tab Bar

    private var tabBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedTab.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppUI.Color.semantic.textPrimary)
                    if let summary = summaryText(for: selectedTab) {
                        Text(summary)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(AppUI.Color.semantic.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                if selectedTab.isContextual {
                    Button {
                        dismissSidebarTab(selectedTab)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 9, weight: .bold))
                            Text("Explorer")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(AppUI.Color.semantic.textSecondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(AppUI.Color.semantic.textTertiary.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                }
                if let badge = badgeValue(for: selectedTab) {
                    Text(badge)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(AppUI.Color.semantic.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(AppUI.Color.semantic.textTertiary.opacity(0.14))
                        )
                }
            }

            HStack(spacing: 6) {
                ForEach(visibleTabs) { tab in
                    sidebarTabButton(for: tab)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.05),
                    Color.black.opacity(0.03),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Open Editor Items

    private var openEditorItems: [EditorOpenEditorItem] {
        sessionStore.tabs.compactMap { tab in
            let group = workbench.leafGroups.first(where: { group in
                group.sessions.contains(where: { $0.id == tab.sessionID })
            })
            let groupIndex = group.flatMap { targetGroup in
                workbench.leafGroups.firstIndex(where: { $0.id == targetGroup.id })
            }
            return EditorOpenEditorItem(
                sessionID: tab.sessionID,
                fileURL: tab.fileURL,
                title: tab.title,
                isDirty: tab.isDirty,
                isPinned: tab.isPinned,
                groupID: group?.id,
                groupIndex: groupIndex,
                isInActiveGroup: group?.id == workbench.activeGroupID,
                isActive: tab.sessionID == sessionStore.activeSessionID,
                recentActivationRank: sessionStore.recentActivationRank(for: tab.sessionID)
            )
        }
        .sorted { lhs, rhs in
            if lhs.isInActiveGroup != rhs.isInActiveGroup {
                return lhs.isInActiveGroup && !rhs.isInActiveGroup
            }
            if lhs.isActive != rhs.isActive {
                return lhs.isActive && !rhs.isActive
            }
            if lhs.recentActivationRank != rhs.recentActivationRank {
                return (lhs.recentActivationRank ?? .max) < (rhs.recentActivationRank ?? .max)
            }
            if lhs.groupIndex != rhs.groupIndex {
                return (lhs.groupIndex ?? .max) < (rhs.groupIndex ?? .max)
            }
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned && !rhs.isPinned
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    // MARK: - Actions

    private func activateOpenEditor(_ item: EditorOpenEditorItem) {
        guard let fileURL = item.fileURL else { return }
        projectVM.selectFile(at: fileURL)
    }

    private func closeOpenEditorItem(_ item: EditorOpenEditorItem) {
        let wasActive = item.sessionID == sessionStore.activeSessionID
        if wasActive, state.hasUnsavedChanges {
            state.saveNow()
        }
        let nextSession = sessionStore.close(sessionID: item.sessionID)
        workbench.close(sessionID: item.sessionID)
        if wasActive {
            if let nextFileURL = nextSession?.fileURL {
                projectVM.selectFile(at: nextFileURL)
            } else {
                projectVM.clearFileSelection()
            }
        }
    }

    private func closeOtherOpenEditorItems(_ item: EditorOpenEditorItem) {
        if state.currentFileURL != item.fileURL, state.hasUnsavedChanges {
            state.saveNow()
        }
        workbench.closeOthers(keeping: item.sessionID)
        let keptSession = sessionStore.closeOthers(keeping: item.sessionID)
        if let fileURL = keptSession?.fileURL {
            projectVM.selectFile(at: fileURL)
        } else {
            projectVM.clearFileSelection()
        }
    }

    private func togglePinnedOpenEditorItem(_ item: EditorOpenEditorItem) {
        sessionStore.togglePinned(sessionID: item.sessionID)
        workbench.groupContainingSession(sessionID: item.sessionID)?.togglePinned(
            sessionID: item.sessionID)
    }

    // MARK: - Tab Selection

    private func selectSidebarTab(_ tab: EditorSidebarWorkspaceTab) {
        persistSidebarWorkspaceSelection(tab)
        switch tab {
        case .explorer:
            state.performPanelCommand(.closeOpenEditors)
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
        case .openEditors:
            if !state.panelState.isOpenEditorsPanelPresented {
                state.performPanelCommand(.toggleOpenEditors)
            } else {
                selectedTab = .openEditors
            }
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
        case .openEditors:
            state.performPanelCommand(.closeOpenEditors)
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

    // MARK: - Tab Bar Helpers

    private var visibleTabs: [EditorSidebarWorkspaceTab] {
        let baseTabs: [EditorSidebarWorkspaceTab] = [.explorer, .openEditors, .outline]
        let contextualTabs = EditorSidebarWorkspaceTab.allCases
            .filter(\.isContextual)
            .filter(shouldShowContextualTab(_:))
            .sorted { $0.priority < $1.priority }
        return baseTabs + contextualTabs
    }

    private func sidebarTabButton(for tab: EditorSidebarWorkspaceTab) -> some View {
        Button {
            selectSidebarTab(tab)
        } label: {
            VStack(spacing: 5) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: tab.systemImage)
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 22, height: 16)

                    if let badge = badgeValue(for: tab) {
                        Text(badge)
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(
                                Capsule()
                                    .fill(
                                        selectedTab == tab
                                            ? AppUI.Color.semantic.primary.opacity(0.16)
                                            : AppUI.Color.semantic.textTertiary.opacity(0.12)
                                    )
                            )
                            .offset(x: 8, y: -4)
                    }
                }
                Rectangle()
                    .fill(
                        selectedTab == tab
                            ? AppUI.Color.semantic.primary.opacity(0.9) : Color.clear
                    )
                    .frame(height: 2)
            }
            .foregroundColor(
                selectedTab == tab
                    ? AppUI.Color.semantic.textPrimary
                    : AppUI.Color.semantic.textSecondary
            )
            .padding(.horizontal, 6)
            .padding(.top, 2)
        }
        .buttonStyle(.plain)
        .help(tab.title)
    }

    private var problemCount: Int {
        state.panelState.semanticProblems.count + state.panelState.problemDiagnostics.count
    }

    private func badgeValue(for tab: EditorSidebarWorkspaceTab) -> String? {
        switch tab {
        case .explorer:
            return nil
        case .openEditors:
            return openEditorItems.isEmpty ? nil : "\(openEditorItems.count)"
        case .outline:
            let count = state.documentSymbolProvider.symbols.count
            return count > 0 ? "\(count)" : nil
        case .problems:
            return problemCount > 0 ? "\(problemCount)" : nil
        case .searchResults:
            let count = state.panelState.workspaceSearchSummary?.totalMatches ?? 0
            return count > 0 ? "\(count)" : nil
        case .references:
            let count = state.panelState.referenceResults.count
            return count > 0 ? "\(count)" : nil
        case .workspaceSymbols:
            let count = state.workspaceSymbolProvider.symbols.count
            return count > 0 ? "\(count)" : nil
        case .callHierarchy:
            let count =
                state.callHierarchyProvider.incomingCalls.count
                + state.callHierarchyProvider.outgoingCalls.count
            return count > 0 ? "\(count)" : nil
        }
    }

    private func shouldShowContextualTab(_ tab: EditorSidebarWorkspaceTab) -> Bool {
        switch tab {
        case .explorer, .openEditors, .outline:
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

    private func summaryText(for tab: EditorSidebarWorkspaceTab) -> String? {
        switch tab {
        case .explorer:
            return nil
        case .openEditors:
            return openEditorItems.isEmpty
                ? "No open editors"
                : "\(openEditorItems.count) open items across active workbench"
        case .outline:
            let count = state.documentSymbolProvider.symbols.count
            if state.documentSymbolProvider.isLoading {
                return "Loading document symbols"
            }
            return count > 0 ? "\(count) symbols in current file" : "No symbols in current file"
        case .problems:
            if problemCount == 0 {
                return "No active diagnostics"
            }
            let fileCount = state.panelState.problemDiagnostics.isEmpty ? 0 : 1
            if fileCount > 0 {
                return "\(problemCount) issues for current file context"
            }
            return "\(problemCount) issues from current project context"
        case .searchResults:
            if state.panelState.isWorkspaceSearchLoading {
                return "Searching workspace"
            }
            if let summary = state.panelState.workspaceSearchSummary {
                return "\(summary.totalMatches) matches in \(summary.totalFiles) files"
            }
            if let query = state.panelState.workspaceSearchQuery.nilIfBlank {
                return "Query: \(query)"
            }
            return "No active workspace query"
        case .references:
            let count = state.panelState.referenceResults.count
            return count > 0 ? "\(count) references in current result set" : "No references loaded"
        case .workspaceSymbols:
            let count = state.workspaceSymbolProvider.symbols.count
            return count > 0 ? "\(count) workspace symbols available" : "No workspace symbols loaded"
        case .callHierarchy:
            if state.callHierarchyProvider.isLoading {
                return "Resolving call hierarchy"
            }
            let incoming = state.callHierarchyProvider.incomingCalls.count
            let outgoing = state.callHierarchyProvider.outgoingCalls.count
            if incoming + outgoing == 0 {
                return "No call hierarchy loaded"
            }
            return "\(incoming) incoming \u{00B7} \(outgoing) outgoing"
        }
    }
}

// MARK: - Content

/// 侧边栏 workspace 内容区
///
/// 根据 selectedTab 切换显示不同的面板视图。
struct EditorSidebarWorkspaceContent: View {
    let selectedTab: EditorSidebarWorkspaceTab
    @ObservedObject var state: EditorState
    let sessionStore: EditorSessionStore
    let workbench: EditorWorkbenchState
    let openEditors: [EditorOpenEditorItem]
    let onSelectOpenEditor: (EditorOpenEditorItem) -> Void
    let onCloseOpenEditor: (EditorOpenEditorItem) -> Void
    let onCloseOtherOpenEditors: (EditorOpenEditorItem) -> Void
    let onTogglePinnedOpenEditor: (EditorOpenEditorItem) -> Void
    let onSelectTab: (EditorSidebarWorkspaceTab) -> Void
    let onDismissTab: (EditorSidebarWorkspaceTab) -> Void

    var body: some View {
        switch selectedTab {
        case .explorer:
            EditorFileTreeView()
        case .openEditors:
            EditorOpenEditorsPanelView(
                state: state,
                items: openEditors,
                onSelect: onSelectOpenEditor,
                onClose: onCloseOpenEditor,
                onCloseOthers: onCloseOtherOpenEditors,
                onTogglePinned: onTogglePinnedOpenEditor,
                showsHeader: false,
                showsResizeHandle: false
            )
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

// MARK: - String Extension

private extension String {
    var nilIfBlank: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}
