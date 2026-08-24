import KernelLumi
import LumiUI
import SwiftUI

public struct BottomEditorProblemsPanelView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @StateObject private var model: ProblemsEditorModel
    public var showsHeader: Bool = true

    public init(editor: any EditorProvidingV2, showsHeader: Bool = true) {
        self._model = StateObject(wrappedValue: ProblemsEditorModel(editor: editor))
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
                model.closePanel()
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
        let count = model.diagnostics.count
        return count > 0 ? LumiPluginLocalization.string("Problems (\(count))", bundle: .module) : LumiPluginLocalization.string("Problems", bundle: .module)
    }

    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                if !model.semanticProblems.isEmpty {
                    sectionLabel(LumiPluginLocalization.string("Project Context", bundle: .module))
                    ForEach(model.semanticProblems) { problem in
                        panelCard(
                            title: problem.title,
                            subtitle: problem.message,
                            badge: "semantic",
                            severity: semanticSeverity(problem.severity)
                        )
                    }
                }
                if model.diagnostics.isEmpty {
                    emptyState(LumiPluginLocalization.string("No Problems", bundle: .module), systemImage: "checkmark.circle")
                } else {
                    sectionLabel(LumiPluginLocalization.string("Diagnostics", bundle: .module))
                    ForEach(model.diagnostics) { diagnostic in
                        let line = diagnostic.range.start.line + 1
                        let column = diagnostic.range.start.character + 1
                        HStack(alignment: .top, spacing: 8) {
                            Button {
                                model.open(diagnostic)
                            } label: {
                                panelCard(
                                    title: "\(model.relativeFilePath):\(line):\(column)",
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
            .padding(10)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.appMicroEmphasized)
            .foregroundColor(theme.textSecondary)
    }

    /// 语义问题严重级别 → 诊断严重级别（共用图标/配色）。
    private func semanticSeverity(_ severity: EditorV2SemanticProblem.Severity) -> EditorDiagnosticSeverity? {
        switch severity {
        case .info: return .information
        case .warning: return .warning
        case .error: return .error
        }
    }

    private func panelCard(title: String, subtitle: String, badge: String, severity: EditorDiagnosticSeverity? = nil) -> some View {
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
}
