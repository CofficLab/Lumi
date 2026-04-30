import SwiftUI

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

struct EditorSidebarWorkspaceView: View {
    @EnvironmentObject private var themeManager: ThemeManager

    @ObservedObject var state: EditorState
    @Binding var selectedTab: EditorSidebarWorkspaceTab
    let openEditors: [EditorOpenEditorItem]
    let onSelectOpenEditor: (EditorOpenEditorItem) -> Void
    let onCloseOpenEditor: (EditorOpenEditorItem) -> Void
    let onCloseOtherOpenEditors: (EditorOpenEditorItem) -> Void
    let onTogglePinnedOpenEditor: (EditorOpenEditorItem) -> Void
    let onSelectTab: (EditorSidebarWorkspaceTab) -> Void
    let onDismissTab: (EditorSidebarWorkspaceTab) -> Void

    private var visibleTabs: [EditorSidebarWorkspaceTab] {
        let baseTabs: [EditorSidebarWorkspaceTab] = [.explorer, .openEditors, .outline]
        let contextualTabs = EditorSidebarWorkspaceTab.allCases
            .filter(\.isContextual)
            .filter(shouldShowContextualTab(_:))
            .sorted { $0.priority < $1.priority }
        return baseTabs + contextualTabs
    }

    private var problemCount: Int {
        state.panelState.semanticProblems.count + state.panelState.problemDiagnostics.count
    }

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            GlassDivider()
            content
        }
        .frame(maxHeight: .infinity)
        .background(themeManager.activeAppTheme.sidebarBackgroundColor())
    }

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
                        onDismissTab(selectedTab)
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
                    Color.black.opacity(0.03)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    @ViewBuilder
    private var content: some View {
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
            EditorOutlinePanelView(
                state: state,
                provider: state.documentSymbolProvider,
                showsHeader: false,
                showsResizeHandle: false
            )
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

    private func sidebarTabButton(for tab: EditorSidebarWorkspaceTab) -> some View {
        Button {
            onSelectTab(tab)
        } label: {
            VStack(spacing: 5) {
                HStack(spacing: 5) {
                    Image(systemName: tab.systemImage)
                        .font(.system(size: 10, weight: .semibold))
                    Text(tab.title)
                        .font(.system(size: 10, weight: .semibold))
                        .lineLimit(1)
                    if let badge = badgeValue(for: tab) {
                        Text(badge)
                            .font(.system(size: 9, weight: .bold, design: .rounded))
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
                    }
                }
                Rectangle()
                    .fill(selectedTab == tab ? AppUI.Color.semantic.primary.opacity(0.9) : Color.clear)
                    .frame(height: 2)
            }
            .foregroundColor(
                selectedTab == tab
                    ? AppUI.Color.semantic.textPrimary
                    : AppUI.Color.semantic.textSecondary
            )
            .padding(.horizontal, 4)
            .padding(.top, 2)
        }
        .buttonStyle(.plain)
    }

    private func badgeValue(for tab: EditorSidebarWorkspaceTab) -> String? {
        switch tab {
        case .explorer:
            return nil
        case .openEditors:
            return openEditors.isEmpty ? nil : "\(openEditors.count)"
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
            let count = state.callHierarchyProvider.incomingCalls.count + state.callHierarchyProvider.outgoingCalls.count
            return count > 0 ? "\(count)" : nil
        }
    }

    private func shouldShowContextualTab(_ tab: EditorSidebarWorkspaceTab) -> Bool {
        switch tab {
        case .explorer, .openEditors, .outline:
            return true
        case .problems:
            return problemCount > 0 || state.panelState.isProblemsPanelPresented || selectedTab == .problems
        case .searchResults:
            return state.panelState.workspaceSearchSummary != nil ||
                !state.panelState.workspaceSearchResults.isEmpty ||
                state.panelState.isWorkspaceSearchLoading ||
                !state.panelState.workspaceSearchQuery.isEmpty ||
                state.panelState.isWorkspaceSearchPresented ||
                selectedTab == .searchResults
        case .references:
            return !state.panelState.referenceResults.isEmpty ||
                state.panelState.isReferencePanelPresented ||
                selectedTab == .references
        case .workspaceSymbols:
            return !state.workspaceSymbolProvider.symbols.isEmpty ||
                state.panelState.isWorkspaceSymbolSearchPresented ||
                selectedTab == .workspaceSymbols
        case .callHierarchy:
            return state.callHierarchyProvider.rootItem != nil ||
                state.callHierarchyProvider.isLoading ||
                state.panelState.isCallHierarchyPresented ||
                selectedTab == .callHierarchy
        }
    }

    private func summaryText(for tab: EditorSidebarWorkspaceTab) -> String? {
        switch tab {
        case .explorer:
            return nil
        case .openEditors:
            return openEditors.isEmpty ? "No open editors" : "\(openEditors.count) open items across active workbench"
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
            return "\(problemCount) issues from current Xcode context"
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

private extension String {
    var nilIfBlank: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}
