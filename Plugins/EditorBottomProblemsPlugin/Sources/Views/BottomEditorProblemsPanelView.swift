import EditorService
import LumiUI
import SwiftUI

public struct BottomEditorProblemsPanelView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @ObservedObject var service: EditorService
    public var showsHeader: Bool = true

    public init(service: EditorService, showsHeader: Bool = true) {
        self._service = ObservedObject(wrappedValue: service)
        self.showsHeader = showsHeader
    }

    public var body: some View {
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
        return count > 0 ? String(localized: "Problems (\(count))", bundle: .module) : String(localized: "Problems", bundle: .module)
    }

    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                if service.panelState.semanticProblems.isEmpty && service.panelState.problemDiagnostics.isEmpty {
                    emptyState(String(localized: "No Problems", bundle: .module), systemImage: "checkmark.circle")
                } else {
                    if !service.panelState.semanticProblems.isEmpty {
                        sectionLabel(String(localized: "Project Context", bundle: .module))
                        ForEach(service.panelState.semanticProblems) { problem in
                            panelCard(title: problem.title, subtitle: problem.message, badge: String(localized: "Project", bundle: .module))
                        }
                    }

                    if !service.panelState.problemDiagnostics.isEmpty {
                        sectionLabel(String(localized: "Diagnostics", bundle: .module))
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
                    .background(
                        Capsule()
                            .fill(theme.textPrimary.opacity(0.08))
                    )
            }

            Text(subtitle)
                .font(.appMicro)
                .foregroundColor(theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .appSurface(style: .custom(theme.textPrimary.opacity(0.035)), cornerRadius: 10)
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
