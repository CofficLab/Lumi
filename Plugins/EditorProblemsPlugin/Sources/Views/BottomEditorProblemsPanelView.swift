import EditorService
import LanguageServerProtocol
import LumiUI
import SwiftUI
import LumiKernel

public struct BottomEditorProblemsPanelView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @ObservedObject var service: EditorService
    @ObservedObject private var panelState: EditorPanelState
    public var showsHeader: Bool = true

    public init(service: EditorService, showsHeader: Bool = true) {
        self._service = ObservedObject(wrappedValue: service)
        self._panelState = ObservedObject(wrappedValue: service.panel.panelState)
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
                service.panel.presentBottomPanel(nil)
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
        let count = panelState.semanticProblems.count + panelState.problemDiagnostics.count
        return count > 0 ? LumiPluginLocalization.string("Problems (\(count))", bundle: .module) : LumiPluginLocalization.string("Problems", bundle: .module)
    }

    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                if panelState.semanticProblems.isEmpty && panelState.problemDiagnostics.isEmpty {
                    emptyState(LumiPluginLocalization.string("No Problems", bundle: .module), systemImage: "checkmark.circle")
                } else {
                    if !panelState.semanticProblems.isEmpty {
                        sectionLabel(LumiPluginLocalization.string("Project Context", bundle: .module))
                        ForEach(panelState.semanticProblems) { problem in
                            HStack(alignment: .top, spacing: 8) {
                                panelCard(
                                    title: problem.title,
                                    subtitle: problem.message,
                                    badge: LumiPluginLocalization.string("Project", bundle: .module),
                                    severity: problem.severity.toDiagnosticSeverity()
                                )
                                ProblemAskAIButton {
                                    sendProblemToChat(problem)
                                }
                            }
                        }
                    }

                    if !panelState.problemDiagnostics.isEmpty {
                        sectionLabel(LumiPluginLocalization.string("Diagnostics", bundle: .module))
                        ForEach(Array(panelState.problemDiagnostics.enumerated()), id: \.offset) { _, diagnostic in
                            let line = Int(diagnostic.range.start.line) + 1
                            let column = Int(diagnostic.range.start.character) + 1
                            HStack(alignment: .top, spacing: 8) {
                                Button {
                                    service.navigation.performOpenItem(.problem(diagnostic))
                                } label: {
                                    panelCard(
                                        title: "\(service.files.relativeFilePath):\(line):\(column)",
                                        subtitle: diagnostic.message,
                                        badge: diagnostic.source ?? "LSP",
                                        severity: diagnostic.severity
                                    )
                                }
                                .buttonStyle(.plain)

                                ProblemAskAIButton {
                                    sendDiagnosticToChat(diagnostic)
                                }
                            }
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

    private func panelCard(title: String, subtitle: String, badge: String, severity: DiagnosticSeverity? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: severityIcon(for: severity))
                    .font(.appMicroEmphasized)
                    .foregroundColor(severityColor(for: severity))
                    .frame(width: 14)

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
                            .fill(severityColor(for: severity).opacity(0.12))
                    )
            }

            Text(subtitle)
                .font(.appMicro)
                .foregroundColor(theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .appSurface(style: .custom(severityColor(for: severity).opacity(0.06)), cornerRadius: 10)
    }

    private func severityIcon(for severity: DiagnosticSeverity?) -> String {
        switch severity {
        case .error: "xmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .information: "info.circle.fill"
        case .hint: "info.circle"
        case .none: "info.circle.fill"
        }
    }

    private func severityColor(for severity: DiagnosticSeverity?) -> SwiftUI.Color {
        switch severity {
        case .error: theme.error
        case .warning: theme.warning
        case .information: theme.info
        case .hint, .none: theme.textSecondary
        }
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

    private var problemPrompt: String {
        LumiPluginLocalization.string("Please help me fix the following problem:", bundle: .module)
    }

    private func sendDiagnosticToChat(_ diagnostic: Diagnostic) {
        ProblemsAddToChat.post(
            ProblemsAddToChat.message(
                for: diagnostic,
                relativeFilePath: service.files.relativeFilePath,
                prompt: problemPrompt
            ),
            windowId: service.state.windowId
        )
    }

    private func sendProblemToChat(_ problem: EditorSemanticProblem) {
        ProblemsAddToChat.post(
            ProblemsAddToChat.message(for: problem, prompt: problemPrompt),
            windowId: service.state.windowId
        )
    }
}

private extension EditorSemanticAvailabilitySeverity {
    func toDiagnosticSeverity() -> DiagnosticSeverity {
        switch self {
        case .error: .error
        case .warning: .warning
        case .info: .information
        }
    }
}
