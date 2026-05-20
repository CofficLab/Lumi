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
            HStack(spacing: 16) {
                // 图标
                Image(systemName: theme.iconName)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? theme.iconColor : Color(hex: "98989E"))
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    // 名称
                    Text(theme.displayName)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(isSelected ? Color.adaptive(light: "1C1C1E", dark: "FFFFFF") : Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))

                    // 描述
                    Text(theme.description)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color(hex: "98989E"))
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
