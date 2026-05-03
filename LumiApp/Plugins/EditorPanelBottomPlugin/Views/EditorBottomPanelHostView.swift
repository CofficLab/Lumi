import SwiftUI
import MagicKit

struct EditorBottomPanelHostView: View {
    @EnvironmentObject private var themeVM: ThemeVM
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
        .background(themeVM.activeAppTheme.workspaceBackgroundColor())
        .overlay(alignment: .top) {
            Rectangle()
                .fill(themeVM.activeAppTheme.workspaceTextColor().opacity(0.08))
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
                        ? themeVM.activeAppTheme.workspaceTextColor()
                        : themeVM.activeAppTheme.workspaceSecondaryTextColor())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(activeBuiltinPanel == panel
                                ? themeVM.activeAppTheme.workspaceTextColor().opacity(0.08)
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
                        ? themeVM.activeAppTheme.workspaceTextColor()
                        : themeVM.activeAppTheme.workspaceSecondaryTextColor())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(activeExtensionPanel?.id == panel.id
                                ? themeVM.activeAppTheme.workspaceTextColor().opacity(0.08)
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
                    .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.05))
    }

    @ViewBuilder
    private var activePanelContent: some View {
        if let activeBuiltinPanel {
            switch activeBuiltinPanel {
            case .problems:
                bottomProblemsContent
            case .references:
                BottomEditorReferencesWorkspacePanelView(state: state, showsHeader: false)
            case .searchResults:
                BottomEditorWorkspaceSearchPanelView(state: state, showsToolbar: true)
            case .workspaceSymbols:
                BottomEditorWorkspaceSymbolsPanelView(state: state, showsHeader: false)
            case .callHierarchy:
                BottomEditorCallHierarchyPanelView(state: state, showsHeader: false)
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
        BottomEditorProblemsPanelView(state: state, showsHeader: false)
    }

    private func emptyState(_ title: String, systemImage: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .thin))
                .foregroundColor(themeVM.activeAppTheme.workspaceTertiaryTextColor())
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 24)
    }
}
