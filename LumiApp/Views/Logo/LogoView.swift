import SwiftUI
import LumiCoreKit

/// A view that renders the highest-priority logo from the plugin registry.
///
/// If the winning `LumiCore.LogoItem` provides an overlay, it is stacked on top
/// via `ZStack`. When no plugin contributes a logo, a transparent placeholder
/// is rendered instead.
struct LogoView: View {
    var scene: LumiCore.LogoScene = .general

    @ObservedObject private var logoRegistry = LumiCore.LumiLogoRegistry.shared

    var body: some View {
        if let item = logoRegistry.bestItem {
            ZStack {
                item.makeView(scene)
                if let overlay = item.makeOverlay {
                    overlay(scene)
                }
            }
        } else {
            // Fallback: 如果没有插件提供 Logo，显示空视图
            Color.clear
                .frame(width: 32, height: 32)
        }
    }
}
