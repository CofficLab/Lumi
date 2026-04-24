import SwiftUI

struct ThemePickerDetailView: View {
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Theme")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)

            if themeManager.themes.isEmpty {
                Text("No themes available")
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                    .padding(.vertical, 8)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(themeManager.themes) { theme in
                            themeRow(theme)
                        }
                    }
                }
                .frame(minHeight: 220)
            }
        }
    }

    @ViewBuilder
    private func themeRow(_ theme: LumiThemeContribution) -> some View {
        let isSelected = theme.id == themeManager.currentThemeId
        Button {
            themeManager.selectTheme(theme.id)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: theme.iconName)
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .white : DesignTokens.Color.semantic.textSecondary)
                    .frame(width: 20, height: 20)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isSelected ? theme.iconColor : DesignTokens.Color.semantic.textTertiary.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(theme.displayName)
                        .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                        .foregroundColor(isSelected ? DesignTokens.Color.semantic.textPrimary : DesignTokens.Color.semantic.textSecondary)
                    Text(theme.description)
                        .font(.system(size: 10))
                        .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(theme.iconColor)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                    .fill(isSelected ? theme.iconColor.opacity(0.12) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
