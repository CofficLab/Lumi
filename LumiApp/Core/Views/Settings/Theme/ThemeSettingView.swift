import SwiftUI

/// 主题设置视图
struct ThemeSettingView: View {
    /// 主题管理器
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                // 主题选择器卡片
                GlassCard {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                        GlassSectionHeader(
                            icon: "paintbrush.fill",
                            title: "主题风格",
                            subtitle: "选择你喜欢的视觉体验"
                        )

                        GlassDivider()

                        ThemeSelectorView()
                            .environmentObject(themeManager)
                    }
                }

                // 主题说明卡片
                GlassCard {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        GlassSectionHeader(
                            icon: "info.circle.fill",
                            title: "关于主题",
                            subtitle: "了解 Lumi 的主题系统"
                        )

                        GlassDivider()

                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            Text("• 精致神秘")
                                .font(DesignTokens.Typography.body)
                                .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                            Text("  以深色为主，配合神秘的紫色光晕和玻璃态效果")
                                .font(DesignTokens.Typography.caption1)
                                .foregroundColor(DesignTokens.Color.semantic.textTertiary)

                            Text("• 清新明亮")
                                .font(DesignTokens.Typography.body)
                                .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                            Text("  以浅色为主，保持清晰明亮的视觉体验")
                                .font(DesignTokens.Typography.caption1)
                                .foregroundColor(DesignTokens.Color.semantic.textTertiary)

                            Text("• 跟随系统")
                                .font(DesignTokens.Typography.body)
                                .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                            Text("  自动根据 macOS 系统外观切换主题")
                                .font(DesignTokens.Typography.caption1)
                                .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                        }
                    }
                }

                Spacer()
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .navigationTitle("主题风格")
    }
}

// MARK: - Preview

#Preview("主题设置") {
    ThemeSettingView()
        .inRootView()
}

#Preview("主题设置 - 完整应用") {
    ContentLayout()
        .hideSidebar()
        .inRootView()
}
