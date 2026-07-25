import LumiKernel
import LumiLocalizationKit
import LumiUI
import SwiftUI

// MARK: - LoadingView

/// 应用启动时的 Loading 页面。
///
/// 复用 LumiUI 的 `AppLoadingOverlay` 作为加载指示器与文案,保证与
/// 设置窗口、插件加载等所有加载态观感一致;外层只补一层 logo 与品牌背景。
struct LoadingView: View {
    @LumiTheme private var theme

    var body: some View {
        ZStack {
            backgroundView

            VStack(spacing: AppUI.Spacing.xxl) {
                Spacer()

                LogoView(scene: .general)
                    .frame(width: 64, height: 64)

                AppLoadingOverlay(
                    message: LumiLocalization.string("Loading components and plugins…", bundle: .module),
                    size: .medium
                )
                .frame(maxWidth: 320)

                Spacer()
                Spacer()
            }
            .padding(.horizontal, AppUI.Spacing.xl)
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
