import SwiftUI
import LumiUI

/// 无活跃容器时的欢迎占位（复刻旧版 `WelcomeView`）。
///
/// 与旧版完全一致：主题色图标 + 标题 + 引导文案 + 主题径向渐变背景。
@MainActor
struct RootWelcomeView: View {
    @LumiTheme private var theme

    var body: some View {
        ZStack {
            backgroundView

            VStack(spacing: DesignTokens.Spacing.xl) {
                Spacer()

                Image(systemName: "rectangle.center.inset.filled")
                    .font(.system(size: 48))
                    .foregroundStyle(theme.primary)
                    .scaledToFit()
                    .frame(maxHeight: 80)

                VStack(spacing: DesignTokens.Spacing.md) {
                    Text(LumiPluginLocalization.string("Welcome to Lumi", bundle: .module))
                        .font(.appTitle)
                        .foregroundStyle(theme.textPrimary)

                    Text(LumiPluginLocalization.string("Select an item from the ActivityBar to get started", bundle: .module))
                        .font(.appBody)
                        .foregroundStyle(theme.textSecondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()
                Spacer()
            }
            .padding(.horizontal, DesignTokens.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
    }

    private var backgroundView: some View {
        GeometryReader { geometry in
            let maxRadius = max(geometry.size.width, geometry.size.height)

            RadialGradient(
                gradient: Gradient(colors: [
                    theme.primary.opacity(0.06),
                    theme.primary.opacity(0.02),
                    theme.background.opacity(0)
                ]),
                center: .center,
                startRadius: 0,
                endRadius: maxRadius * 0.8
            )
            .ignoresSafeArea()
        }
    }
}
