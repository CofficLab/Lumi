import LumiKernel
import LumiLocalizationKit
import LumiUI
import SwiftUI

// MARK: - WelcomeView

/// 空状态欢迎视图.
///
/// 在没有活跃容器时显示,引导用户从 ActivityBar 选择入口.
struct WelcomeView: View {
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
                    Text(LumiLocalization.string("Welcome to Lumi", bundle: .module))
                        .font(.appTitle)
                        .foregroundStyle(theme.textPrimary)

                    Text(LumiLocalization.string(
                        "Select an item from the ActivityBar to get started",
                        bundle: .module
                    ))
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

// MARK: - Preview

#if DEBUG
    #Preview("WelcomeView") {
        WelcomeView()
    }

    #Preview("WelcomeView - Light") {
        WelcomeView()
            .preferredColorScheme(.light)
    }

    #Preview("WelcomeView - Dark") {
        WelcomeView()
            .preferredColorScheme(.dark)
    }
#endif
