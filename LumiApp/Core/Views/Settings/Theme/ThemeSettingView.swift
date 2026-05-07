import SwiftUI

/// 主题设置视图
struct ThemeSettingView: View {
    /// 主题管理器
    @EnvironmentObject private var themeVM: ThemeVM

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
                    .environmentObject(themeVM)
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
        .inRootView()
}
