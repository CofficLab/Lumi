import LumiKernel
import LumiUI
import SwiftUI

/// 应用 Logo 视图
///
/// 从插件 kernel 的 LogoManager 读取已注册的 Logo 并显示。
/// 根据 scene 查找匹配的最高优先级 Logo,未找到时使用内置 SF Symbol
/// (回退图标配 `theme.primary` 着色,保证未注册 logo 时观感也跟随主题)。
struct LogoView: View {
    @LumiTheme private var theme

    let scene: LogoScene
    let kernel: LumiKernel?

    init(scene: LogoScene = .general, kernel: LumiKernel? = nil) {
        self.scene = scene
        self.kernel = kernel
    }

    private var logoItem: LogoItem? {
        kernel?.logo?.allLogoItems
            .max { $0.order < $1.order }
    }

    private var logoView: AnyView? {
        logoItem?.makeView(scene)
    }

    var body: some View {
        Group {
            if let view = logoView {
                view
            } else {
                fallbackView
            }
        }
        .accessibilityLabel("Logo")
    }

    @ViewBuilder
    private var fallbackView: some View {
        switch scene {
        case .about:
            Image(systemName: "app.fill")
                .resizable()
                .scaledToFit()
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(theme.primary)
        case .statusBar:
            Image(systemName: "sparkles")
                .resizable()
                .scaledToFit()
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(theme.primary)
        default:
            Image(systemName: "sparkles")
                .resizable()
                .scaledToFit()
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(theme.primary)
        }
    }
}
