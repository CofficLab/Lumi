import EditorService
import LanguageServerProtocol
import LumiKernel
import LumiUI
import SwiftUI

enum ProblemsPanelIDs {
    static let bottomTab = "editor-bottom-problems"
}

/// Problems 诊断状态栏项目。
struct ProblemsDiagnosticStatusBarView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @ObservedObject private var editorService: EditorService
    @ObservedObject private var panelState: EditorPanelState
    private let onPresentPanel: () -> Void

    init(editorService: EditorService, onPresentPanel: @escaping () -> Void) {
        self._editorService = ObservedObject(wrappedValue: editorService)
        self._panelState = ObservedObject(wrappedValue: editorService.panel.panelState)
        self.onPresentPanel = onPresentPanel
    }

    var body: some View {
        if hasDiagnostics {
            StatusBarHoverContainer(
                detailView: ProblemsDiagnosticStatusBarDetailView(
                    editorService: editorService,
                    panelState: panelState,
                    onPresentPanel: onPresentPanel
                ),
                popoverWidth: 480,
                id: "problems-diagnostics"
            ) {
                indicators
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
        }
    }

    private var diagnostics: [Diagnostic] {
        panelState.problemDiagnostics
    }

    private var hasDiagnostics: Bool {
        errorCount > 0 || warningCount > 0 || !panelState.semanticProblems.isEmpty
    }

    private var errorCount: Int {
        diagnostics.filter { $0.severity == .error }.count
    }

    private var warningCount: Int {
        diagnostics.filter { $0.severity == .warning }.count
    }

    @ViewBuilder
    private var indicators: some View {
        HStack(spacing: 8) {
            if errorCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(theme.error)
                    Text("\(errorCount)")
                        .font(.appMicroEmphasized)
                }
            }

            if warningCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(theme.warning)
                    Text("\(warningCount)")
                        .font(.appMicroEmphasized)
                }
            }
        }
    }
}

private struct ProblemsDiagnosticStatusBarDetailView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @ObservedObject var editorService: EditorService
    @ObservedObject var panelState: EditorPanelState
    let onPresentPanel: () -> Void

    private var diagnostics: [Diagnostic] {
        panelState.problemDiagnostics
    }

    private var errorCount: Int {
        diagnostics.filter { $0.severity == .error }.count
    }

    private var warningCount: Int {
        diagnostics.filter { $0.severity == .warning }.count
    }

    var body: some View {
        StatusBarPopoverScaffold(
            title: LumiPluginLocalization.string("Problems", bundle: .module),
            systemImage: "exclamationmark.bubble",
            subtitle: summaryText,
            headerAccessory: { EmptyView() },
            content: {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        if diagnostics.isEmpty, panelState.semanticProblems.isEmpty {
                            Text(LumiPluginLocalization.string("No problems in the current file.", bundle: .module))
                                .foregroundColor(theme.textSecondary)
                        } else {
                            if !panelState.semanticProblems.isEmpty {
                                sectionLabel(LumiPluginLocalization.string("Project Context", bundle: .module))
                                ForEach(panelState.semanticProblems) { problem in
                                    diagnosticRow(
                                        title: problem.title,
                                        message: problem.message,
                                        badge: LumiPluginLocalization.string("Project", bundle: .module),
                                        systemImage: severityIcon(for: problem.severity.toDiagnosticSeverity()),
                                        tint: severityColor(for: problem.severity.toDiagnosticSeverity()),
                                        askAI: {
                                            sendProblemToChat(problem)
                                        }
                                    )
                                }
                            }

                            if !diagnostics.isEmpty {
                                sectionLabel(LumiPluginLocalization.string("Diagnostics", bundle: .module))
                                ForEach(Array(diagnostics.enumerated()), id: \.offset) { _, diagnostic in
                                    HStack(alignment: .top, spacing: 8) {
                                        Button {
                                            editorService.navigation.performOpenItem(.problem(diagnostic))
                                        } label: {
                                            diagnosticRow(
                                                title: locationLabel(for: diagnostic),
                                                message: diagnostic.message,
                                                badge: diagnostic.source ?? "LSP",
                                                systemImage: severityIcon(for: diagnostic.severity),
                                                tint: severityColor(for: diagnostic.severity)
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
                }
                .frame(minHeight: 180, maxHeight: 360)
            },
            footer: {
                Button(LumiPluginLocalization.string("Open Problems Panel", bundle: .module)) {
                    onPresentPanel()
                    HoverCoordinator.shared.close(id: "problems-diagnostics")
                }
                .buttonStyle(.plain)
            }
        )
    }

    private var summaryText: String {
        switch (errorCount, warningCount) {
        case (0, 0):
            return LumiPluginLocalization.string("Current file", bundle: .module)
        case let (errors, 0):
            return "\(errors) error\(errors == 1 ? "" : "s")"
        case let (0, warnings):
            return "\(warnings) warning\(warnings == 1 ? "" : "s")"
        case let (errors, warnings):
            return "\(errors) error\(errors == 1 ? "" : "s"), \(warnings) warning\(warnings == 1 ? "" : "s")"
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.appMicroEmphasized)
            .foregroundColor(theme.textSecondary)
    }

    private func diagnosticRow(
        title: String,
        message: String,
        badge: String,
        systemImage: String,
        tint: SwiftUI.Color,
        askAI: (() -> Void)? = nil
    ) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: systemImage)
                .font(.appMicroEmphasized)
                .foregroundColor(tint)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.appCaptionEmphasized)
                        .foregroundColor(theme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(badge)
                        .font(.appMicroEmphasized)
                        .foregroundColor(theme.textSecondary)
                }

                Text(message)
                    .font(.appMicro)
                    .foregroundColor(theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let askAI {
                ProblemAskAIButton(action: askAI)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
    }

    private var problemPrompt: String {
        LumiPluginLocalization.string("Please help me fix the following problem:", bundle: .module)
    }

    private func sendDiagnosticToChat(_ diagnostic: Diagnostic) {
        ProblemsAddToChat.post(
            ProblemsAddToChat.message(
                for: diagnostic,
                relativeFilePath: editorService.files.relativeFilePath,
                prompt: problemPrompt
            ),
            windowId: editorService.state.windowId
        )
    }

    private func sendProblemToChat(_ problem: EditorSemanticProblem) {
        ProblemsAddToChat.post(
            ProblemsAddToChat.message(for: problem, prompt: problemPrompt),
            windowId: editorService.state.windowId
        )
    }

    private func locationLabel(for diagnostic: Diagnostic) -> String {
        let line = Int(diagnostic.range.start.line) + 1
        let column = Int(diagnostic.range.start.character) + 1
        return "\(editorService.files.relativeFilePath):\(line):\(column)"
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
