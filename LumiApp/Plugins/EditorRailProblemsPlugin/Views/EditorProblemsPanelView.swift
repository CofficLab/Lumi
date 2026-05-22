import SwiftUI
import LumiUI

struct EditorProblemsPanelView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

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
                .font(.appCaptionEmphasized)
                .foregroundColor(theme.textPrimary)

            Spacer(minLength: 0)

            Button {
                service.presentBottomPanel(nil)
            } label: {
                Image(systemName: "xmark")
                    .font(.appMicroEmphasized)
                    .foregroundColor(theme.textSecondary)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private var panelTitle: String {
        let count = service.panelState.semanticProblems.count + service.panelState.problemDiagnostics.count
        return count > 0 ? String(localized: "\(count) Problems", table: "EditorRailProblems") : String(localized: "Problems", table: "EditorRailProblems")
    }

    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                if service.panelState.semanticProblems.isEmpty && service.panelState.problemDiagnostics.isEmpty {
                    emptyState(String(localized: "No Problems", table: "EditorRailProblems"), systemImage: "checkmark.circle")
                } else {
                    if !service.panelState.semanticProblems.isEmpty {
                        sectionLabel(String(localized: "Project Context", table: "EditorRailProblems"))
                        ForEach(service.panelState.semanticProblems) { problem in
                            panelCard(title: problem.title, subtitle: problem.message, badge: String(localized: "Project", table: "EditorRailProblems"))
                        }
                    }

                    if !service.panelState.problemDiagnostics.isEmpty {
                        sectionLabel(String(localized: "Diagnostics", table: "EditorRailProblems"))
                        ForEach(Array(service.panelState.problemDiagnostics.enumerated()), id: \.offset) { _, diagnostic in
                            let line = Int(diagnostic.range.start.line) + 1
                            let column = Int(diagnostic.range.start.character) + 1
                            Button {
                                service.performOpenItem(.problem(diagnostic))
                            } label: {
                                panelCard(
                                    title: "\(service.relativeFilePath):\(line):\(column)",
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
            .font(.appMicroEmphasized)
            .foregroundColor(theme.textSecondary)
    }

    private func panelCard(title: String, subtitle: String, badge: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                Text(title)
                    .font(.appCaptionEmphasized)
                    .foregroundColor(theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(badge)
                    .font(.appMicroEmphasized)
                    .foregroundColor(theme.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .appSurface(style: .subtle, cornerRadius: 999)
            }

            Text(subtitle)
                .font(.appMicro)
                .foregroundColor(theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .appSurface(style: .subtle, cornerRadius: 10)
    }

    private func emptyState(_ title: String, systemImage: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.appTitle)
                .foregroundColor(theme.textSecondary)
            Text(title)
                .font(.appCaption)
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
