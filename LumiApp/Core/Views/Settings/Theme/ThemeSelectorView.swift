import SwiftUI
import LumiUI

// MARK: - 主题选择器
///
/// 用于选择和切换不同的神秘主题
///
struct ThemeSelectorView: View {
    // MARK: - 环境
    @EnvironmentObject private var themeVM: AppThemeVM

    // MARK: - 主体
    var body: some View {
        VStack(spacing: 8) {
            ForEach(themeVM.themes) { theme in
                ThemeOptionCard(
                    theme: theme,
                    isSelected: themeVM.currentThemeId == theme.id
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        themeVM.selectTheme(theme.id)
                    }
                }
            }
        }
    }
}

// MARK: - 主题选项卡片
struct ThemeOptionCard: View {
    @LumiUI.LumiTheme private var appTheme: any LumiUITheme

    let theme: LumiUIThemeContribution
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        GlassSelectionCard(
            isSelected: isSelected,
            checkmarkColor: theme.iconColor,
            selectedBackgroundColor: theme.iconColor.opacity(0.15),
            selectedBorderColor: theme.iconColor,
            action: action
        ) {
            HStack(spacing: 16) {
                // 图标
                Image(systemName: theme.iconName)
                    .font(.appTitle)
                    .foregroundColor(isSelected ? theme.iconColor : appTheme.textTertiary)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    // 名称
                    Text(theme.displayName)
                        .font(.appBody)
                        .foregroundColor(isSelected ? appTheme.textPrimary : appTheme.textSecondary)

                    // 描述
                    Text(theme.description)
                        .font(.appCaption)
                        .foregroundColor(appTheme.textTertiary)
                }
            }
        }
    }
}

// MARK: - 预览
#Preview("主题选择器") {
    ThemeSelectorView()
        .mystiqueBackground()
        .environmentObject(AppThemeVM())
}
