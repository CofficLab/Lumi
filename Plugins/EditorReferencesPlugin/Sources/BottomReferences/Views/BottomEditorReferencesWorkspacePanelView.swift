import EditorService
import LumiUI
import SwiftUI
import LumiKernel

public struct BottomEditorReferencesWorkspacePanelView: View {
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
                service.panel.performPanelCommand(.closeReferences)
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
        let count = service.panel.panelState.referenceResults.count
        return count > 0 ? LumiPluginLocalization.string("References (\(count))", bundle: .module) : LumiPluginLocalization.string("References", bundle: .module)
    }

    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                if service.panel.panelState.referenceResults.isEmpty {
                    emptyState(LumiPluginLocalization.string("No References", bundle: .module), systemImage: "arrow.triangle.branch")
                } else {
                    ForEach(service.panel.panelState.referenceResults) { item in
                        Button {
                            service.navigation.performOpenItem(
                                .reference(
                                    .init(
                                        url: item.url,
                                        line: item.line,
                                        column: item.column,
                                        path: item.path,
                                        preview: item.preview
                                    )
                                )
                            )
                        } label: {
                            panelCard(
                                title: "\(item.path):\(item.line):\(item.column)",
                                subtitle: item.preview,
                                badge: LumiPluginLocalization.string("Reference", bundle: .module),
                                isSelected: service.panel.panelState.selectedReferenceResult == item
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(10)
        }
    }

    private func panelCard(title: String, subtitle: String, badge: String, isSelected: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(badge)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(theme.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(theme.textPrimary.opacity(0.05))
                    .clipShape(Capsule())
            }

            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    isSelected
                        ? theme.textPrimary.opacity(0.1)
                        : theme.textPrimary.opacity(0.05)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            isSelected
                                ? theme.textPrimary.opacity(0.18)
                                : Color.clear,
                            lineWidth: 1
                        )
                )
        )
    }

    private func emptyState(_ title: String, systemImage: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .thin))
                .foregroundColor(theme.textTertiary)
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 24)
    }
}
