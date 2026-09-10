import LumiUI
import SwiftUI

/// 首次启动欢迎页 —— 展示 Lumi 品牌与产品定位。
struct WelcomePage: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg - 2) {
            Image(systemName: "sparkles")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(theme.primary)
            VStack(spacing: DesignTokens.Spacing.sm) {
                Text(LumiPluginLocalization.string("Welcome to Lumi", bundle: .module))
                    .font(DesignTokens.Typography.largeTitle)
                Text(LumiPluginLocalization.string("Your local workspace for focused AI conversations, projects, and tools.", bundle: .module))
                    .font(DesignTokens.Typography.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .frame(maxWidth: 520)
        .padding(.vertical, DesignTokens.Spacing.lg)
    }
}
