import SwiftUI
import LumiUI

/// 主题设置视图
struct ThemeSettingView: View {
    /// 主题管理器
    @EnvironmentObject private var themeVM: AppThemeVM

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 主题选择器卡片
                themeSelectorCard

                Spacer()
            }
            .padding(24)
        }
    }

    // MARK: - Theme Selector Card

    private var themeSelectorCard: some View {
        AppCard {
            AppSettingsSection(title: "选择主题", subtitle: "点击主题卡片即可切换", spacing: 12) {
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
