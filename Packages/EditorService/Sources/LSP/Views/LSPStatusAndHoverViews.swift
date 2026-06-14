import EditorKernel
import LanguageServerProtocol
import LumiUI
import SwiftUI

/// LSP 诊断状态栏项目。
///
/// 展示当前文件诊断中的错误和警告数量，支持悬停/点击弹出详情，并可跳转到 Problems 面板。
public struct LSPDiagnosticStatusBarItem: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @ObservedObject private var editorService: EditorService
    @StateObject private var diagnosticsManager: DiagnosticsManager

    public init(editorService: EditorService) {
        self._editorService = ObservedObject(wrappedValue: editorService)
        self._diagnosticsManager = StateObject(wrappedValue: DiagnosticsManager())
    }

    public var body: some View {
        if hasDiagnostics {
            StatusBarHoverContainer(
                detailView: LSPDiagnosticStatusBarDetailView(
                    editorService: editorService,
                    diagnosticsManager: diagnosticsManager
                ),
                popoverWidth: 480,
                id: "lsp-diagnostics"
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

private struct LSPDiagnosticStatusBarDetailView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @ObservedObject var editorService: EditorService
    @ObservedObject var diagnosticsManager: DiagnosticsManager

    var body: some View {
        StatusBarPopoverScaffold(
            title: "Problems",
            systemImage: "exclamationmark.bubble",
            subtitle: summaryText,
            headerAccessory: { EmptyView() },
            content: {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        if diagnosticsManager.diagnostics.isEmpty,
                           editorService.panel.panelState.semanticProblems.isEmpty {
                            Text("No problems in the current file.")
                                .foregroundColor(theme.textSecondary)
                        } else {
                            if !editorService.panel.panelState.semanticProblems.isEmpty {
                                sectionLabel("Project Context")
                                ForEach(editorService.panel.panelState.semanticProblems) { problem in
                                    diagnosticRow(
                                        title: problem.title,
                                        message: problem.message,
                                        badge: "Project",
                                        systemImage: "exclamationmark.triangle.fill",
                                        tint: theme.warning
                                    )
                                }
                            }

                            if !diagnosticsManager.diagnostics.isEmpty {
                                sectionLabel("Diagnostics")
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
                Button("Open Problems Panel") {
                    editorService.panel.presentBottomPanel(.problems)
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
            return "Current file"
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

/// LSP Hover 简易提示浮层。
///
/// 用于展示一段纯文本 hover 内容。当前编辑器主流程更多使用 Markdown hover popover，
/// 该视图保留为 LSP 服务插件内的轻量展示组件。
public struct LSPHoverTooltip: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    public let content: String

    public var body: some View {
        Text(content)
            .font(.appMonoCaption)
            .foregroundColor(theme.textPrimary)
            .padding(8)
            .frame(maxWidth: 400, alignment: .leading)
            .appSurface(style: .popover, cornerRadius: 6, borderColor: theme.divider)
            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 2)
    }
}
