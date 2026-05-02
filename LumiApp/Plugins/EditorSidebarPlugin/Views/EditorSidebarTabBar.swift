import SwiftUI

// MARK: - Tab Bar

/// 编辑器侧边栏 Tab Bar 视图
///
/// 包含标题、摘要、徽章和可点击的标签按钮。
struct EditorSidebarTabBar: View {
    @EnvironmentObject private var editorVM: EditorVM

    let selectedTab: EditorSidebarWorkspaceTab
    let visibleTabs: [EditorSidebarWorkspaceTab]
    let onTabSelect: (EditorSidebarWorkspaceTab) -> Void
    let onDismiss: (EditorSidebarWorkspaceTab) -> Void

    private var state: EditorState { editorVM.service.state }

    var body: some View {
        tabBarButtons
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

    // MARK: - Tab Buttons

    private var tabBarButtons: some View {
        HStack(spacing: 6) {
            ForEach(visibleTabs) { tab in
                sidebarTabButton(for: tab)
            }
            Spacer(minLength: 0)
        }
    }

    @State private var hoverState: [EditorSidebarWorkspaceTab: Bool] = [:]

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
                    : (hoverState[tab] == true
                        ? AppUI.Color.semantic.textPrimary
                        : AppUI.Color.semantic.textSecondary)
            )
            .padding(.horizontal, 6)
            .padding(.top, 2)
            .background(
                hoverState[tab] == true && selectedTab != tab
                    ? AppUI.Color.semantic.textPrimary.opacity(0.08)
                    : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help(tab.title)
        .contentShape(RoundedRectangle(cornerRadius: 6))
        .onHover { isHovered in
            hoverState[tab] = isHovered
        }
    }

    // MARK: - Helpers

    private var problemCount: Int {
        state.panelState.semanticProblems.count + state.panelState.problemDiagnostics.count
    }

    private func badgeValue(for tab: EditorSidebarWorkspaceTab) -> String? {
        switch tab {
        case .explorer:
            return nil
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

}
