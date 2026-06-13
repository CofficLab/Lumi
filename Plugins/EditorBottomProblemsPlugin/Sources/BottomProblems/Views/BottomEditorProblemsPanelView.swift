import EditorService
import LumiUI
import SwiftUI
import LumiCoreKit

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
        let count = service.panel.panelState.semanticProblems.count + service.panel.panelState.problemDiagnostics.count
        return count > 0 ? LumiPluginLocalization.string("Problems (\(count))", bundle: .module) : LumiPluginLocalization.string("Problems", bundle: .module)
    }

    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                if service.panel.panelState.semanticProblems.isEmpty && service.panel.panelState.problemDiagnostics.isEmpty {
                    emptyState(LumiPluginLocalization.string("No Problems", bundle: .module), systemImage: "checkmark.circle")
                } else {
                    if !service.panel.panelState.semanticProblems.isEmpty {
                        sectionLabel(LumiPluginLocalization.string("Project Context", bundle: .module))
                        ForEach(service.panel.panelState.semanticProblems) { problem in
                            panelCard(title: problem.title, subtitle: problem.message, badge: LumiPluginLocalization.string("Project", bundle: .module))
                        }
                    }

                    if !service.panel.panelState.problemDiagnostics.isEmpty {
                        sectionLabel(LumiPluginLocalization.string("Diagnostics", bundle: .module))
                        ForEach(Array(service.panel.panelState.problemDiagnostics.enumerated()), id: \.offset) { _, diagnostic in
                            let line = Int(diagnostic.range.start.line) + 1
                            let column = Int(diagnostic.range.start.character) + 1
                            Button {
                                service.navigation.performOpenItem(.problem(diagnostic))
                            } label: {
                                panelCard(
                                    title: "\(service.files.relativeFilePath):\(line):\(column)",
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
