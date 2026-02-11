import SwiftUI

/// 主题设置视图
struct ThemeSettingView: View {
    /// 主题管理器
    @EnvironmentObject private var themeManager: MystiqueThemeManager

    var body: some View {
        ZStack {
            // 背景
            Color.clear
                .mystiqueBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                    // 页面标题
                    header

                    // 主题选择器
                    themeSelector

                    // 当前主题信息
                    currentThemeInfo

                    // 主题效果说明
                    themeGuide

                    Spacer()
                }
                .padding(DesignTokens.Spacing.lg)
            }
        }
        .navigationTitle("主题风格")
        .colorScheme(.dark) // 强制使用深色模式，确保 DesignTokens 颜色显示正确
    }

    // MARK: - 页面标题

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "paintbrush.fill")
                    .font(.system(size: 28))
                    .foregroundColor(DesignTokens.Color.semantic.primary)

                Text("主题风格")
                    .font(DesignTokens.Typography.title2)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)
            }

            Text("选择你喜欢的神秘主题风格，打造独特的视觉体验")
                .font(DesignTokens.Typography.body)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
        }
    }

    // MARK: - 主题选择器

    private var themeSelector: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("选择主题风格")
                .font(DesignTokens.Typography.title3)
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)

            // 主题选择器
            ThemeSelectorView(displayMode: .full, showHeader: false, showPreview: true)
                .environmentObject(themeManager)
        }
    }

    // MARK: - 当前主题信息

    private var currentThemeInfo: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("当前主题")
                .font(DesignTokens.Typography.title3)
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)

            MystiqueGlassCard {
                HStack(spacing: DesignTokens.Spacing.md) {
                    // 主题图标
                    ZStack {
                        Circle()
                            .fill(themeManager.currentVariant.theme.iconColor.opacity(0.2))
                            .frame(width: 48, height: 48)

                        Image(systemName: themeManager.currentVariant.theme.iconName)
                            .font(.system(size: 20))
                            .foregroundColor(themeManager.currentVariant.theme.iconColor)
                    }

                    // 主题信息
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text(themeManager.currentVariant.theme.displayName)
                            .font(DesignTokens.Typography.bodyEmphasized)
                            .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                        Text(themeManager.currentVariant.theme.description)
                            .font(DesignTokens.Typography.caption1)
                            .foregroundColor(DesignTokens.Color.semantic.textTertiary)

                        // 主题效果预览
                        HStack(spacing: DesignTokens.Spacing.xs) {
                            Label("背景", systemImage: "rectangle.fill")
                                .font(DesignTokens.Typography.caption2)
                                .foregroundColor(DesignTokens.Color.semantic.textTertiary)

                            Circle()
                                .fill(themeManager.currentVariant.theme.iconColor)
                                .frame(width: 12, height: 12)

                            Label("光晕", systemImage: "sparkles")
                                .font(DesignTokens.Typography.caption2)
                                .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                        }
                    }

                    Spacer()
                }
            }
            .mystiqueGlow(intensity: 0.15)
        }
    }

    // MARK: - 主题效果说明

    private var themeGuide: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("主题效果")
                .font(DesignTokens.Typography.title3)
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                themeFeatureCard(
                    icon: "sparkles",
                    title: "动态光晕",
                    description: "每个主题都有独特的光晕效果，随当前主题色变化"
                )

                themeFeatureCard(
                    icon: "paintbrush.fill",
                    title: "玻璃质感",
                    description: "所有卡片和组件都采用统一的玻璃态设计风格"
                )

                themeFeatureCard(
                    icon: "eye.fill",
                    title: "视觉一致性",
                    description: "主题色会应用到整个应用，确保视觉体验统一"
                )
            }
        }
    }

    /// 主题特性卡片
    private func themeFeatureCard(
        icon: String,
        title: String,
        description: String
    ) -> some View {
        MystiqueGlassCard(cornerRadius: DesignTokens.Radius.sm, padding: DesignTokens.Spacing.compactPadding) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(DesignTokens.Color.semantic.primary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(title)
                        .font(DesignTokens.Typography.bodyEmphasized)
                        .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                    Text(description)
                        .font(DesignTokens.Typography.caption1)
                        .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                }

                Spacer()
            }
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
        .hideTabPicker()
        .inRootView()
}
