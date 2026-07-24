import LumiKernel
import LumiUI
import SwiftUI

/// 应用 Logo 视图
///
/// 从插件 kernel 的 LogoManager 读取已注册的 Logo 并显示。
/// 根据 scene 查找匹配的最高优先级 Logo，未找到时使用内置 SF Symbol。
struct LogoView: View {
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
        case .statusBar:
            Image(systemName: "sparkles")
                .resizable()
                .scaledToFit()
        default:
            Image(systemName: "sparkles")
                .resizable()
                .scaledToFit()
        }
    }
}
