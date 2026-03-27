import SwiftUI

/// 主题设置视图
struct ThemeSettingView: View {
    /// 主题管理器
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                // 顶部说明卡片
                headerCard

                // 主题选择器卡片
                themeSelectorCard

                // 主题说明卡片
                themeDescriptionCard

                Spacer()
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .navigationTitle("主题风格")
    }

    // MARK: - Header Card

    private var headerCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                GlassSectionHeader(
                    icon: "paintbrush.fill",
                    title: "主题风格",
                    subtitle: "选择你喜欢的视觉体验"
                )

                GlassDivider()

                HStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(DesignTokens.Color.semantic.primary)
                        .font(.system(size: 14))

                    Text("选择不同的主题风格，自定义应用的外观和氛围")
                        .font(DesignTokens.Typography.caption1)
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                }
            }
        }
    }

    // MARK: - Theme Selector Card

    private var themeSelectorCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                GlassSectionHeader(
                    icon: "swatchpalette",
                    title: "选择主题",
                    subtitle: "点击主题卡片即可切换"
                )

                GlassDivider()

                ThemeSelectorView()
                    .environmentObject(themeManager)
            }
        }
    }

    // MARK: - Theme Description Card

    private var themeDescriptionCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                GlassSectionHeader(
                    icon: "info.circle.fill",
                    title: "主题说明",
                    subtitle: "了解不同主题的特点"
                )

                GlassDivider()

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    themeDescriptionItem(
                        icon: "moon.stars.fill",
                        title: "精致神秘",
                        description: "以深色为主，配合神秘的紫色光晕和玻璃态效果"
                    )

                    themeDescriptionItem(
                        icon: "sun.max.fill",
                        title: "清新明亮",
                        description: "以浅色为主，保持清晰明亮的视觉体验"
                    )

                    themeDescriptionItem(
                        icon: "desktopcomputer",
                        title: "跟随系统",
                        description: "自动根据 macOS 系统外观切换主题"
                    )
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func themeDescriptionItem(icon: String, title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.Color.semantic.primary)

                Text(title)
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)
            }

            Text(description)
                .font(DesignTokens.Typography.caption1)
                .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                .padding(.leading, 18)
        }
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
