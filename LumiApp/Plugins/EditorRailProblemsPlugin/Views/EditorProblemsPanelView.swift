import SwiftUI
import MagicKit

struct EditorProblemsPanelView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject var state: EditorState
    var showsHeader: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            if showsHeader {
                header
                Divider()
            }
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(panelTitle)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(themeManager.activeAppTheme.workspaceTextColor())

            Spacer(minLength: 0)

            Button {
                state.presentBottomPanel(nil)
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
    }

    private var panelTitle: String {
        let count = state.panelState.semanticProblems.count + state.panelState.problemDiagnostics.count
        return count > 0 ? String(localized: "\(count) Problems", table: "EditorRailProblems") : String(localized: "Problems", table: "EditorRailProblems")
    }

    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                if state.panelState.semanticProblems.isEmpty && state.panelState.problemDiagnostics.isEmpty {
                    emptyState(String(localized: "No Problems", table: "EditorRailProblems"), systemImage: "checkmark.circle")
                } else {
                    if !state.panelState.semanticProblems.isEmpty {
                        sectionLabel(String(localized: "Project Context", table: "EditorRailProblems"))
                        ForEach(state.panelState.semanticProblems) { problem in
                            panelCard(title: problem.title, subtitle: problem.message, badge: String(localized: "Project", table: "EditorRailProblems"))
                        }
                    }

                    if !state.panelState.problemDiagnostics.isEmpty {
                        sectionLabel(String(localized: "Diagnostics", table: "EditorRailProblems"))
                        ForEach(Array(state.panelState.problemDiagnostics.enumerated()), id: \.offset) { _, diagnostic in
                            let line = Int(diagnostic.range.start.line) + 1
                            let column = Int(diagnostic.range.start.character) + 1
                            Button {
                                state.performOpenItem(.problem(diagnostic))
                            } label: {
                                panelCard(
                                    title: "\(state.relativeFilePath):\(line):\(column)",
                                    subtitle: diagnostic.message,
                                    badge: diagnostic.source ?? String(localized: "LSP", table: "EditorRailProblems")
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(10)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(themeManager.activeAppTheme.workspaceSecondaryTextColor())
    }

    private func panelCard(title: String, subtitle: String, badge: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(themeManager.activeAppTheme.workspaceTextColor())
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(badge)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(themeManager.activeAppTheme.workspaceSecondaryTextColor())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(themeManager.activeAppTheme.workspaceTextColor().opacity(0.08))
                    )
            }

            Text(subtitle)
                .font(.system(size: 11))
                .foregroundColor(themeManager.activeAppTheme.workspaceSecondaryTextColor())
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(themeManager.activeAppTheme.workspaceTextColor().opacity(0.035))
        )
    }

    private func emptyState(_ title: String, systemImage: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(themeManager.activeAppTheme.workspaceSecondaryTextColor())
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(themeManager.activeAppTheme.workspaceSecondaryTextColor())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
