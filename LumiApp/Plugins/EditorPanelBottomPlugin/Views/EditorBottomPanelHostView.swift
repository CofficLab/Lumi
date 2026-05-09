import SwiftUI
import MagicKit

struct EditorBottomPanelHostView: View {
    @EnvironmentObject private var themeVM: ThemeVM
    @ObservedObject var service: EditorService
    @State private var activeExtensionPanelID: String?

    /// 有内容时的默认面板高度（首次使用时）
    private let defaultPanelHeight: CGFloat = 280

    /// Tab 栏高度
    private let tabBarHeight: CGFloat = 33

    /// 所有内置面板类型，始终显示
    private var allBuiltinPanels: [EditorBottomPanelKind] {
        EditorBottomPanelKind.allCases
    }

    private var activeBuiltinPanel: EditorBottomPanelKind? {
        service.panelState.activeBottomPanel
    }

    private var visibleExtensionPanels: [EditorPanelSuggestion] {
        service.editorExtensions.panelSuggestions(state: service.state)
            .filter { $0.placement == .bottom && $0.isPresented(service.state) }
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

    /// 是否有任何面板处于激活状态
    private var hasActivePanel: Bool {
        activeBuiltinPanel != nil || activeExtensionPanel != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .fixedSize(horizontal: false, vertical: true)

            if hasActivePanel {
                Divider()
                activePanelContent
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeVM.activeAppTheme.workspaceBackgroundColor())
        .overlay(alignment: .top) {
            Rectangle()
                .fill(themeVM.activeAppTheme.workspaceTextColor().opacity(0.08))
                .frame(height: 1)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            // 所有内置面板 Tab，始终显示
            ForEach(allBuiltinPanels, id: \.self) { panel in
                Button {
                    activeExtensionPanel?.onDismiss(service.state)
                    activeExtensionPanelID = nil
                    service.presentBottomPanel(panel)
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
                        activeExtensionPanel?.onDismiss(service.state)
                    }
                    service.presentBottomPanel(nil)
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

            if hasActivePanel {
                Button {
                    activeExtensionPanel?.onDismiss(service.state)
                    service.presentBottomPanel(nil)
                    activeExtensionPanelID = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
            }
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
                BottomEditorReferencesWorkspacePanelView(service: service, showsHeader: false)
            case .searchResults:
                BottomEditorWorkspaceSearchPanelView(service: service, showsToolbar: true)
            case .workspaceSymbols:
                BottomEditorWorkspaceSymbolsPanelView(service: service, showsHeader: false)
            case .callHierarchy:
                BottomEditorCallHierarchyPanelView(service: service, showsHeader: false)
            }
        } else if let activeExtensionPanel {
            activeExtensionPanel.content(service.state)
                .frame(maxWidth: .infinity)
        } else {
            Color.clear
        }
    }

    private func tabTitle(for panel: EditorBottomPanelKind) -> String {
        switch panel {
        case .problems:
            let count = service.panelState.semanticProblems.count + service.panelState.problemDiagnostics.count
            return count > 0 ? "\(panel.title) (\(count))" : panel.title
        case .references:
            let count = service.panelState.referenceResults.count
            return count > 0 ? "\(panel.title) (\(count))" : panel.title
        case .searchResults:
            let count = service.panelState.workspaceSearchSummary?.totalMatches ?? 0
            return count > 0 ? "\(panel.title) (\(count))" : panel.title
        case .workspaceSymbols:
            let count = service.workspaceSymbolProvider.symbols.count
            return count > 0 ? "\(panel.title) (\(count))" : panel.title
        case .callHierarchy:
            let count = service.callHierarchyProvider.incomingCalls.count + service.callHierarchyProvider.outgoingCalls.count
            return count > 0 ? "\(panel.title) (\(count))" : panel.title
        }
    }

    private var bottomProblemsContent: some View {
        BottomEditorProblemsPanelView(service: service, showsHeader: false)
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
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}
