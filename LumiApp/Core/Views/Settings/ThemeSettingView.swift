import SwiftUI

/// 主题设置视图
struct ThemeSettingView: View {
    /// 主题管理器
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        ZStack {
            // 背景
            Color.clear
                .mystiqueBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                    // 主题选择器
                    themeSelector

                    Spacer()
                }
                .padding(DesignTokens.Spacing.lg)
            }
        }
        .navigationTitle("主题风格")
    }

    // MARK: - 主题选择器

    private var themeSelector: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            // 主题选择器
            ThemeSelectorView(displayMode: .full, showHeader: false, showPreview: false)
                .environmentObject(themeManager)
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
