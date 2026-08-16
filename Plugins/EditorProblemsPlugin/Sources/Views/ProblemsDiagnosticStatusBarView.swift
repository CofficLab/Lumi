import KernelLumi
import LumiUI
import SwiftUI

enum ProblemsPanelIDs {
    static let bottomTab = "editor-bottom-problems"
}

/// Problems 诊断状态栏项目。
struct ProblemsDiagnosticStatusBarView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @StateObject private var model: ProblemsEditorModel
    private let onPresentPanel: () -> Void

    init(editor: any EditorProvidingV2, onPresentPanel: @escaping () -> Void) {
        self._model = StateObject(wrappedValue: ProblemsEditorModel(editor: editor))
        self.onPresentPanel = onPresentPanel
    }

    var body: some View {
        if hasDiagnostics {
            StatusBarHoverContainer(
                detailView: ProblemsDiagnosticStatusBarDetailView(
                    model: model,
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

    private var hasDiagnostics: Bool {
        model.errorCount > 0 || model.warningCount > 0
    }

    @ViewBuilder
    private var indicators: some View {
        HStack(spacing: 8) {
            if model.errorCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(theme.error)
                    Text("\(model.errorCount)")
                        .font(.appMicroEmphasized)
                }
            }

            if model.warningCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(theme.warning)
                    Text("\(model.warningCount)")
                        .font(.appMicroEmphasized)
                }
            }
        }
    }
}

private struct ProblemsDiagnosticStatusBarDetailView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @ObservedObject var model: ProblemsEditorModel
    let onPresentPanel: () -> Void

    var body: some View {
        StatusBarPopoverScaffold(
            title: LumiPluginLocalization.string("Problems", bundle: .module),
            systemImage: "exclamationmark.bubble",
            subtitle: summaryText,
            headerAccessory: { EmptyView() },
            content: {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        // 语义问题（EditorSemanticProblem）暂无 V2 等价能力，
                        // 该分区在 Phase 5 语义能力落地后恢复。
                        if model.diagnostics.isEmpty {
                            Text(LumiPluginLocalization.string("No problems in the current file.", bundle: .module))
                                .foregroundColor(theme.textSecondary)
                        } else {
                            sectionLabel(LumiPluginLocalization.string("Diagnostics", bundle: .module))
                            ForEach(model.diagnostics) { diagnostic in
                                HStack(alignment: .top, spacing: 8) {
                                    Button {
                                        model.open(diagnostic)
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
        switch (model.errorCount, model.warningCount) {
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

    private func sendDiagnosticToChat(_ diagnostic: EditorDiagnosticItem) {
        ProblemsAddToChat.post(
            ProblemsAddToChat.message(
                for: diagnostic,
                relativeFilePath: model.relativeFilePath,
                prompt: problemPrompt
            ),
            windowId: model.editor.scope.windowID.rawValue
        )
    }

    private func locationLabel(for diagnostic: EditorDiagnosticItem) -> String {
        let line = diagnostic.range.start.line + 1
        let column = diagnostic.range.start.character + 1
        return "\(model.relativeFilePath):\(line):\(column)"
    }

    private func severityIcon(for severity: EditorDiagnosticSeverity?) -> String {
        switch severity {
        case .error: "xmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .information: "info.circle.fill"
        case .hint: "info.circle"
        case .none: "info.circle.fill"
        }
    }

    private func severityColor(for severity: EditorDiagnosticSeverity?) -> SwiftUI.Color {
        switch severity {
        case .error: theme.error
        case .warning: theme.warning
        case .information: theme.info
        case .hint, .none: theme.textSecondary
        }
    }
}
