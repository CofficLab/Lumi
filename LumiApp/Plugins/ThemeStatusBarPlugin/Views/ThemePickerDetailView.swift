import SwiftUI
import LumiUI

struct ThemePickerDetailView: View {
    @LumiUI.LumiTheme private var uiTheme: any LumiUITheme
    @EnvironmentObject private var themeVM: AppThemeVM

    var body: some View {
        StatusBarPopoverScaffold(
            title: String(localized: "Theme", table: "ThemeStatusBar"),
            systemImage: "paintbrush"
        ) {
            if themeVM.themes.isEmpty {
                AppEmptyState(
                    icon: "paintbrush",
                    title: LocalizedStringKey(String(localized: "No themes available", table: "ThemeStatusBar"))
                )
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
    private func themeRow(_ theme: LumiUIThemeContribution) -> some View {
        let isSelected = theme.id == themeVM.currentThemeId
        AppListRow(isSelected: isSelected, action: {
            themeVM.selectTheme(theme.id)
        }) {
            HStack(spacing: 10) {
                Image(systemName: theme.iconName)
                    .font(.appCaptionEmphasized)
                    .foregroundColor(isSelected ? .white : uiTheme.textSecondary)
                    .frame(width: 20, height: 20)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isSelected ? theme.iconColor : uiTheme.textTertiary.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(theme.displayName)
                        .font(isSelected ? .appCaptionEmphasized : .appCaption)
                        .foregroundColor(isSelected ? uiTheme.textPrimary : uiTheme.textSecondary)
                    Text(theme.description)
                        .font(.appMicro)
                        .foregroundColor(uiTheme.textTertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.appMicroEmphasized)
                        .foregroundColor(theme.iconColor)
                }
            }
        }
    }
}
