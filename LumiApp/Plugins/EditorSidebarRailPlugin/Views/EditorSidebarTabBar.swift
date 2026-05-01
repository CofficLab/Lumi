import SwiftUI

// MARK: - Tab Bar

/// 编辑器侧边栏 Tab Bar 视图
///
/// 包含标题、摘要、徽章和可点击的标签按钮。
struct EditorSidebarTabBar: View {
    @EnvironmentObject private var editorVM: EditorVM

    let selectedTab: EditorSidebarWorkspaceTab
    let visibleTabs: [EditorSidebarWorkspaceTab]
    let openEditorItems: [EditorOpenEditorItem]
    let onTabSelect: (EditorSidebarWorkspaceTab) -> Void
    let onDismiss: (EditorSidebarWorkspaceTab) -> Void

    private var state: EditorState { editorVM.state }

    var body: some View {
        VStack(spacing: 8) {
            tabBarHeader
            tabBarButtons
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

    // MARK: - Header

    private var tabBarHeader: some View {
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
                dismissButton
            }
            if let badge = badgeValue(for: selectedTab) {
                badgeView(badge)
            }
        }
    }

    private var dismissButton: some View {
        Button {
            onDismiss(selectedTab)
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

    private func badgeView(_ badge: String) -> some View {
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

    // MARK: - Tab Buttons

    private var tabBarButtons: some View {
        HStack(spacing: 6) {
            ForEach(visibleTabs) { tab in
                sidebarTabButton(for: tab)
            }
            Spacer(minLength: 0)
        }
    }

    private func sidebarTabButton(for tab: EditorSidebarWorkspaceTab) -> some View {
        Button {
            onTabSelect(tab)
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

    // MARK: - Helpers

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

// MARK: - String Extension

private extension String {
    var nilIfBlank: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}
