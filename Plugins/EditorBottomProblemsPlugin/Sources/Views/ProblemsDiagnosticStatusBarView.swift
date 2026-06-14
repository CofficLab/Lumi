import EditorService
import LanguageServerProtocol
import LumiCoreKit
import LumiUI
import SwiftUI

enum ProblemsPanelIDs {
    static let bottomTab = "editor-bottom-problems"
}

/// Problems 诊断状态栏项目。
struct ProblemsDiagnosticStatusBarView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @ObservedObject private var editorService: EditorService
    @StateObject private var diagnosticsManager: DiagnosticsManager
    private let onPresentPanel: () -> Void

    init(editorService: EditorService, onPresentPanel: @escaping () -> Void) {
        self._editorService = ObservedObject(wrappedValue: editorService)
        self._diagnosticsManager = StateObject(wrappedValue: DiagnosticsManager())
        self.onPresentPanel = onPresentPanel
    }

    var body: some View {
        if hasDiagnostics {
            StatusBarHoverContainer(
                detailView: ProblemsDiagnosticStatusBarDetailView(
                    editorService: editorService,
                    diagnosticsManager: diagnosticsManager,
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
        diagnosticsManager.errorCount > 0
            || diagnosticsManager.warningCount > 0
            || !editorService.panel.panelState.semanticProblems.isEmpty
    }

    @ViewBuilder
    private var indicators: some View {
        HStack(spacing: 8) {
            if diagnosticsManager.errorCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(theme.error)
                    Text("\(diagnosticsManager.errorCount)")
                        .font(.appMicroEmphasized)
                }
            }

            if diagnosticsManager.warningCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(theme.warning)
                    Text("\(diagnosticsManager.warningCount)")
                        .font(.appMicroEmphasized)
                }
            }
        }
    }
}

private struct ProblemsDiagnosticStatusBarDetailView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @ObservedObject var editorService: EditorService
    @ObservedObject var diagnosticsManager: DiagnosticsManager
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
                        if diagnosticsManager.diagnostics.isEmpty,
                           editorService.panel.panelState.semanticProblems.isEmpty {
                            Text(LumiPluginLocalization.string("No problems in the current file.", bundle: .module))
                                .foregroundColor(theme.textSecondary)
                        } else {
                            if !editorService.panel.panelState.semanticProblems.isEmpty {
                                sectionLabel(LumiPluginLocalization.string("Project Context", bundle: .module))
                                ForEach(editorService.panel.panelState.semanticProblems) { problem in
                                    diagnosticRow(
                                        title: problem.title,
                                        message: problem.message,
                                        badge: LumiPluginLocalization.string("Project", bundle: .module),
                                        systemImage: "exclamationmark.triangle.fill",
                                        tint: theme.warning
                                    )
                                }
                            }

                            if !diagnosticsManager.diagnostics.isEmpty {
                                sectionLabel(LumiPluginLocalization.string("Diagnostics", bundle: .module))
                                ForEach(Array(diagnosticsManager.diagnostics.enumerated()), id: \.offset) { _, diagnostic in
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
                }
                .buttonStyle(.plain)
            }
        )
    }

    private var summaryText: String {
        let errors = diagnosticsManager.errorCount
        let warnings = diagnosticsManager.warningCount
        switch (errors, warnings) {
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
        tint: SwiftUI.Color
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
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
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
        case .information, .hint, .none: "info.circle.fill"
        }
    }

    private func severityColor(for severity: DiagnosticSeverity?) -> SwiftUI.Color {
        switch severity {
        case .error: theme.error
        case .warning: theme.warning
        case .information, .hint, .none: theme.textSecondary
        }
    }
}
