import SwiftUI

/// 主题设置视图
struct ThemeSettingView: View {
    /// 主题管理器
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 0) {
            // 顶部说明卡片（固定）
            headerCard
                .padding(AppUI.Spacing.lg)
                .background(Color.clear)

            ScrollView {
                VStack(alignment: .leading, spacing: AppUI.Spacing.lg) {
                    // 主题选择器卡片
                    themeSelectorCard

                    // 主题说明卡片
                    themeDescriptionCard

                    Spacer()
                }
                .padding(.horizontal, AppUI.Spacing.lg)
            }
        }
        .navigationTitle("主题风格")
    }

    // MARK: - Header Card

    private var headerCard: some View {
        GlassCard {
            GlassSectionHeader(
                icon: "paintbrush.fill",
                title: "主题风格",
                subtitle: "选择你喜欢的视觉体验"
            )
        }
    }

    // MARK: - Theme Selector Card

    private var themeSelectorCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppUI.Spacing.md) {
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
            VStack(alignment: .leading, spacing: AppUI.Spacing.sm) {
                GlassSectionHeader(
                    icon: "info.circle.fill",
                    title: "主题说明",
                    subtitle: "了解不同主题的特点"
                )

                GlassDivider()

                VStack(alignment: .leading, spacing: AppUI.Spacing.xs) {
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
        VStack(alignment: .leading, spacing: AppUI.Spacing.xs) {
            HStack(spacing: AppUI.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(AppUI.Color.semantic.primary)

                Text(title)
                    .font(AppUI.Typography.body)
                    .foregroundColor(AppUI.Color.semantic.textPrimary)
            }

            Text(description)
                .font(AppUI.Typography.caption1)
                .foregroundColor(AppUI.Color.semantic.textTertiary)
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
