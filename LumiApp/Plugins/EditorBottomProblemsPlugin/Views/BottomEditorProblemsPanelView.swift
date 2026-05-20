import SwiftUI

struct BottomEditorProblemsPanelView: View {
    @EnvironmentObject private var themeVM: AppThemeVM
    @ObservedObject var service: EditorService
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
                .foregroundColor(themeVM.activeAppTheme.workspaceTextColor())

            Spacer(minLength: 0)

            Button {
                service.presentBottomPanel(nil)
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
    }

    private var panelTitle: String {
        let count = service.panelState.semanticProblems.count + service.panelState.problemDiagnostics.count
        return count > 0 ? String(localized: "Problems (\(count))", table: "EditorBottomProblems") : String(localized: "Problems", table: "EditorBottomProblems")
    }

    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                if service.panelState.semanticProblems.isEmpty && service.panelState.problemDiagnostics.isEmpty {
                    emptyState(String(localized: "No Problems", table: "EditorBottomProblems"), systemImage: "checkmark.circle")
                } else {
                    if !service.panelState.semanticProblems.isEmpty {
                        sectionLabel(String(localized: "Project Context", table: "EditorBottomProblems"))
                        ForEach(service.panelState.semanticProblems) { problem in
                            panelCard(title: problem.title, subtitle: problem.message, badge: String(localized: "Project", table: "EditorBottomProblems"))
                        }
                    }

                    if !service.panelState.problemDiagnostics.isEmpty {
                        sectionLabel(String(localized: "Diagnostics", table: "EditorBottomProblems"))
                        ForEach(Array(service.panelState.problemDiagnostics.enumerated()), id: \.offset) { _, diagnostic in
                            let line = Int(diagnostic.range.start.line) + 1
                            let column = Int(diagnostic.range.start.character) + 1
                            Button {
                                service.performOpenItem(.problem(diagnostic))
                            } label: {
                                panelCard(
                                    title: "\(service.relativeFilePath):\(line):\(column)",
                                    subtitle: diagnostic.message,
                                    badge: diagnostic.source ?? "LSP"
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
            .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
    }

    private func panelCard(title: String, subtitle: String, badge: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(themeVM.activeAppTheme.workspaceTextColor())
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(badge)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(themeVM.activeAppTheme.workspaceTextColor().opacity(0.08))
                    )
            }

            Text(subtitle)
                .font(.system(size: 11))
                .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(themeVM.activeAppTheme.workspaceTextColor().opacity(0.035))
        )
    }

    private func emptyState(_ title: String, systemImage: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
