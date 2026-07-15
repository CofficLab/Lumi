import SwiftUI
import LumiCoreKit

/// A view that renders the highest-priority logo from the plugin registry.
///
/// If the winning `LumiCore.LogoItem` provides an overlay, it is stacked on top
/// via `ZStack`. When no plugin contributes a logo, a SF Symbol fallback is rendered.
struct LogoView: View {
    let scene: LogoScene
    let lumiCore: LumiCoreAccessing

    init(scene: LogoScene = .general, lumiCore: LumiCoreAccessing) {
        self.scene = scene
        self.lumiCore = lumiCore
    }

    var body: some View {
        // logoRegistry 是 LumiCore 共享的全局单例,从传入的 lumiCore 实例获取。
        // SwiftUI 通过对 lumiCore 的 objectWillChange 订阅来重绘,
        // 而 logoRegistry 自身的 @Published 变化由 lumiCore 转播。
        if let item = lumiCore.logoRegistry.bestItem {
            ZStack {
                item.makeView(scene)
                if let overlay = item.makeOverlay {
                    overlay(scene)
                }
            }
        } else {
            // Fallback: 没有插件提供 Logo 时，显示一个 SF Symbol 作为内置默认 Logo
            Image(systemName: "sparkles")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.secondary)
                .accessibilityLabel("Logo")
        }
    }
}
