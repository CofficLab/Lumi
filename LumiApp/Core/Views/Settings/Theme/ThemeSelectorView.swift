import SwiftUI

// MARK: - 主题选择器
///
/// 用于选择和切换不同的神秘主题
///
struct ThemeSelectorView: View {
    // MARK: - 环境
    @EnvironmentObject private var themeManager: ThemeManager

    // MARK: - 主体
    var body: some View {
        VStack(spacing: AppUI.Spacing.sm) {
            ForEach(themeManager.themes) { theme in
                ThemeOptionCard(
                    theme: theme,
                    isSelected: themeManager.currentThemeId == theme.id
                ) {
                    withAnimation(DesignAnimations.Preset.bounce) {
                        themeManager.selectTheme(theme.id)
                    }
                }
            }
        }
    }
}

// MARK: - 主题选项卡片
struct ThemeOptionCard: View {
    let theme: LumiThemeContribution
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
            HStack(spacing: AppUI.Spacing.md) {
                // 图标
                Image(systemName: theme.iconName)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? theme.iconColor : AppUI.Color.semantic.textTertiary)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: AppUI.Spacing.xs) {
                    // 名称
                    Text(theme.displayName)
                        .font(AppUI.Typography.body)
                        .foregroundColor(isSelected ? AppUI.Color.semantic.textPrimary : AppUI.Color.semantic.textSecondary)

                    // 描述
                    Text(theme.description)
                        .font(AppUI.Typography.caption1)
                        .foregroundColor(AppUI.Color.semantic.textTertiary)
                }
            }
        }
    }
}

// MARK: - 预览
#Preview("主题选择器") {
    ThemeSelectorView()
        .mystiqueBackground()
        .environmentObject(ThemeManager())
}
