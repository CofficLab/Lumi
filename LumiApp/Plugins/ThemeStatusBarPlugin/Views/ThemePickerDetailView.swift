import SwiftUI

struct ThemePickerDetailView: View {
    @EnvironmentObject private var themeVM: ThemeVM

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "Theme", table: "ThemeStatusBar"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))

            if themeVM.themes.isEmpty {
                Text(String(localized: "No themes available", table: "ThemeStatusBar"))
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "98989E"))
                    .padding(.vertical, 8)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(themeVM.themes) { theme in
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
        let isSelected = theme.id == themeVM.currentThemeId
        Button {
            themeVM.selectTheme(theme.id)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: theme.iconName)
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .white : Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                    .frame(width: 20, height: 20)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isSelected ? theme.iconColor : Color(hex: "98989E").opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(theme.displayName)
                        .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                        .foregroundColor(
                            isSelected
                                ? Color.adaptive(light: "1C1C1E", dark: "FFFFFF")
                                : Color.adaptive(light: "6B6B7B", dark: "EBEBF5")
                        )
                    Text(theme.description)
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "98989E"))
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
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? theme.iconColor.opacity(0.12) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
