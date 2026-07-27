import LumiKernel
import LumiLocalizationKit
import LumiUI
import SwiftUI

// MARK: - LoadingView

/// 应用启动时的 Loading 页面。
///
/// 用 ProgressView + 主题文案呈现加载态,观感与设置窗口、插件加载一致;
/// 外层补一层 logo 与品牌渐变背景。
///
/// 注:不复用 LumiUI 的 `AppLoadingOverlay` —— 它的 `message` 入参是
/// `LocalizedStringKey`,而这里文案走 `LumiLocalization.string(...)`(返回 String),
/// 类型不兼容,故用内联的 ProgressView + Text。
struct LoadingView: View {
    @LumiTheme private var theme

    var body: some View {
        ZStack {
            backgroundView

            VStack(spacing: DesignTokens.Spacing.xxl) {
                Spacer()

                LogoView(scene: .general)
                    .frame(width: 64, height: 64)

                VStack(spacing: DesignTokens.Spacing.md) {
                    ProgressView()
                        .scaleEffect(1.0)
                    Text(LumiLocalization.string("Loading components and plugins…", bundle: .module))
                        .font(.appCaption)
                        .foregroundColor(theme.textSecondary)
                }
                .frame(maxWidth: 320)

                Spacer()
                Spacer()
            }
            .padding(.horizontal, DesignTokens.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
    }

    // MARK: - Background

    private var backgroundView: some View {
        GeometryReader { geometry in
            let maxRadius = max(geometry.size.width, geometry.size.height)

            RadialGradient(
                gradient: Gradient(colors: [
                    theme.primary.opacity(0.08),
                    theme.primary.opacity(0.03),
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
    #Preview("LoadingView") {
        LoadingView()
    }

    #Preview("LoadingView - Light") {
        LoadingView()
        .preferredColorScheme(.light)
    }

    #Preview("LoadingView - Dark") {
        LoadingView()
        .preferredColorScheme(.dark)
    }
#endif
