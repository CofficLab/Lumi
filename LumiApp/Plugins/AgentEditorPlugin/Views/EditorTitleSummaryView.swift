import SwiftUI
import MagicKit

struct EditorTitleSummaryView: View {
    @EnvironmentObject private var themeManager: ThemeManager

    @ObservedObject private var state: EditorState
    let metadata: EditorTitleMetadata
    let trailingItems: [EditorStatusItemSuggestion]

    init(
        state: EditorState,
        metadata: EditorTitleMetadata,
        trailingItems: [EditorStatusItemSuggestion] = []
    ) {
        self._state = ObservedObject(wrappedValue: state)
        self.metadata = metadata
        self.trailingItems = trailingItems
    }

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(metadata.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(themeManager.activeAppTheme.workspaceTextColor())
                    .lineLimit(1)

                if let subtitle = metadata.subtitle {
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundColor(themeManager.activeAppTheme.workspaceSecondaryTextColor())
                        .lineLimit(1)
                }
            }

            if !metadata.badges.isEmpty {
                HStack(spacing: 6) {
                    ForEach(metadata.badges, id: \.self) { badge in
                        badgeView(badge)
                    }
                }
            }

            Spacer(minLength: 0)

            Text(metadata.languageLabel)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(themeManager.activeAppTheme.workspaceSecondaryTextColor())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(themeManager.activeAppTheme.workspaceTextColor().opacity(0.05))
                .clipShape(Capsule())

            ForEach(trailingItems) { item in
                item.content(state)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(themeManager.activeAppTheme.workspaceTertiaryTextColor().opacity(0.04))
    }

    @ViewBuilder
    private func badgeView(_ badge: EditorTitleMetadata.Badge) -> some View {
        Text(badge.title)
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(badgeForegroundColor(badge))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(badgeBackgroundColor(badge))
            .clipShape(Capsule())
    }

    private func badgeForegroundColor(_ badge: EditorTitleMetadata.Badge) -> Color {
        switch badge {
        case .dirty:
            return AppUI.Color.semantic.warning
        case .readOnly:
            return AppUI.Color.semantic.textSecondary
        case .pinned:
            return AppUI.Color.semantic.primary
        case .preview:
            return themeManager.activeAppTheme.workspaceSecondaryTextColor()
        }
    }

    private func badgeBackgroundColor(_ badge: EditorTitleMetadata.Badge) -> Color {
        switch badge {
        case .dirty:
            return AppUI.Color.semantic.warning.opacity(0.12)
        case .readOnly:
            return AppUI.Color.semantic.textTertiary.opacity(0.12)
        case .pinned:
            return AppUI.Color.semantic.primary.opacity(0.10)
        case .preview:
            return themeManager.activeAppTheme.workspaceTextColor().opacity(0.05)
        }
    }
}
