import SwiftUI
import MagicKit

struct EditorReferencesWorkspacePanelView: View {
    @EnvironmentObject private var themeVM: ThemeVM
    @ObservedObject var state: EditorState
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
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(themeVM.activeAppTheme.workspaceTextColor())

            Spacer(minLength: 0)

            Button {
                state.performPanelCommand(.closeReferences)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private var panelTitle: String {
        let count = state.panelState.referenceResults.count
        return count > 0 ? String(localized: "\(count) References", table: "EditorRailReferences") : String(localized: "References", table: "EditorRailReferences")
    }

    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                if state.panelState.referenceResults.isEmpty {
                    emptyState(String(localized: "No References", table: "EditorRailReferences"), systemImage: "arrow.triangle.branch")
                } else {
                    ForEach(state.panelState.referenceResults) { item in
                        Button {
                            state.performOpenItem(
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
                                badge: String(localized: "Reference", table: "EditorRailReferences"),
                                isSelected: state.panelState.selectedReferenceResult == item
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
                    .foregroundColor(themeVM.activeAppTheme.workspaceTextColor())
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(badge)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(themeVM.activeAppTheme.workspaceTextColor().opacity(0.05))
                    .clipShape(Capsule())
            }

            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
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
                        ? themeVM.activeAppTheme.workspaceTextColor().opacity(0.1)
                        : themeVM.activeAppTheme.workspaceTextColor().opacity(0.05)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            isSelected
                                ? themeVM.activeAppTheme.workspaceTextColor().opacity(0.18)
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
                .foregroundColor(themeVM.activeAppTheme.workspaceTertiaryTextColor())
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 24)
    }
}
