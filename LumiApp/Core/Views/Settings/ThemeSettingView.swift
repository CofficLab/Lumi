import SwiftUI

/// 主题设置视图
struct ThemeSettingView: View {
    /// 主题管理器
    @EnvironmentObject private var themeManager: MystiqueThemeManager

    /// 当前配色方案（用于预览展示）
    @Environment(\.colorScheme) private var colorScheme

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

                    Spacer()
                }
                .padding(DesignTokens.Spacing.lg)
            }
        }
        .navigationTitle("主题风格")
    }

    // MARK: - 页面标题

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "paintbrush.fill")
                    .font(.system(size: 28))
                    .foregroundColor(DesignTokens.Color.adaptive.primary)

                Text("主题风格")
                    .font(DesignTokens.Typography.title2)
                    .foregroundColor(DesignTokens.Color.adaptive.textPrimary(for: colorScheme))
            }
        }
    }

    // MARK: - 主题选择器

    private var themeSelector: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {

            // 主题选择器
            ThemeSelectorView(displayMode: .full, showHeader: false, showPreview: true)
                .environmentObject(themeManager)
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
