import SwiftUI
import MagicKit

struct EditorBottomPanelHostView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject var state: EditorState
    @State private var activeExtensionPanelID: String?

    private let panelHeight: CGFloat = 280

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            activePanelContent
        }
        .frame(maxWidth: .infinity)
        .frame(height: panelHeight)
        .background(themeManager.activeAppTheme.workspaceBackgroundColor())
        .overlay(alignment: .top) {
            Rectangle()
                .fill(themeManager.activeAppTheme.workspaceTextColor().opacity(0.08))
                .frame(height: 1)
        }
    }

    private var visibleBuiltinPanels: [EditorBottomPanelKind] {
        state.panelState.visibleBottomPanels
    }

    private var activeBuiltinPanel: EditorBottomPanelKind? {
        state.panelState.activeBottomPanel
    }

    private var visibleExtensionPanels: [EditorPanelSuggestion] {
        state.editorExtensions.panelSuggestions(state: state)
            .filter { $0.placement == .bottom && $0.isPresented(state) }
            .sorted { lhs, rhs in
                if lhs.order != rhs.order { return lhs.order < rhs.order }
                return lhs.id.localizedCaseInsensitiveCompare(rhs.id) == .orderedAscending
            }
    }

    private var activeExtensionPanel: EditorPanelSuggestion? {
        if let activeExtensionPanelID {
            return visibleExtensionPanels.first { $0.id == activeExtensionPanelID }
        }
        return visibleExtensionPanels.first
    }

    private var header: some View {
        HStack(spacing: 8) {
            ForEach(visibleBuiltinPanels, id: \.self) { panel in
                Button {
                    activeExtensionPanel?.onDismiss(state)
                    activeExtensionPanelID = nil
                    state.presentBottomPanel(panel)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: panel.icon)
                            .font(.system(size: 10, weight: .semibold))
                        Text(tabTitle(for: panel))
                            .font(.system(size: 11, weight: activeBuiltinPanel == panel ? .semibold : .medium))
                    }
                    .foregroundColor(activeBuiltinPanel == panel
                        ? themeManager.activeAppTheme.workspaceTextColor()
                        : themeManager.activeAppTheme.workspaceSecondaryTextColor())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(activeBuiltinPanel == panel
                                ? themeManager.activeAppTheme.workspaceTextColor().opacity(0.08)
                                : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }

            ForEach(visibleExtensionPanels) { panel in
                Button {
                    if activeExtensionPanel?.id != panel.id {
                        activeExtensionPanel?.onDismiss(state)
                    }
                    state.presentBottomPanel(nil)
                    activeExtensionPanelID = panel.id
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: panel.systemImage)
                            .font(.system(size: 10, weight: .semibold))
                        Text(panel.title)
                            .font(.system(size: 11, weight: activeExtensionPanel?.id == panel.id ? .semibold : .medium))
                    }
                    .foregroundColor(activeExtensionPanel?.id == panel.id
                        ? themeManager.activeAppTheme.workspaceTextColor()
                        : themeManager.activeAppTheme.workspaceSecondaryTextColor())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(activeExtensionPanel?.id == panel.id
                                ? themeManager.activeAppTheme.workspaceTextColor().opacity(0.08)
                                : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)

            Button {
                activeExtensionPanel?.onDismiss(state)
                state.presentBottomPanel(nil)
                activeExtensionPanelID = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(themeManager.activeAppTheme.workspaceSecondaryTextColor())
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(themeManager.activeAppTheme.workspaceTertiaryTextColor().opacity(0.05))
    }

    @ViewBuilder
    private var activePanelContent: some View {
        if let activeBuiltinPanel {
            switch activeBuiltinPanel {
            case .problems:
                bottomProblemsContent
            case .references:
                EditorReferencesWorkspacePanelView(state: state, showsHeader: false)
            case .searchResults:
                EditorWorkspaceSearchPanelView(state: state, showsToolbar: true)
            case .workspaceSymbols:
                EditorWorkspaceSymbolsPanelView(state: state, showsHeader: false)
            case .callHierarchy:
                EditorCallHierarchyPanelView(state: state, showsHeader: false)
            }
        } else if let activeExtensionPanel {
            activeExtensionPanel.content(state)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Color.clear
        }
    }

    private func tabTitle(for panel: EditorBottomPanelKind) -> String {
        switch panel {
        case .problems:
            let count = state.panelState.semanticProblems.count + state.panelState.problemDiagnostics.count
            return "\(panel.title) (\(count))"
        case .references:
            return "\(panel.title) (\(state.panelState.referenceResults.count))"
        case .searchResults:
            let count = state.panelState.workspaceSearchSummary?.totalMatches ?? 0
            return count > 0 ? "\(panel.title) (\(count))" : panel.title
        case .workspaceSymbols:
            let count = state.workspaceSymbolProvider.symbols.count
            return count > 0 ? "\(panel.title) (\(count))" : panel.title
        case .callHierarchy:
            let count = state.callHierarchyProvider.incomingCalls.count + state.callHierarchyProvider.outgoingCalls.count
            return count > 0 ? "\(panel.title) (\(count))" : panel.title
        }
    }

    private var bottomProblemsContent: some View {
        EditorProblemsPanelView(state: state, showsHeader: false)
    }

    private func emptyState(_ title: String, systemImage: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .thin))
                .foregroundColor(themeManager.activeAppTheme.workspaceTertiaryTextColor())
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(themeManager.activeAppTheme.workspaceSecondaryTextColor())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 24)
    }
}
