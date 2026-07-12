import SwiftUI
import LumiCoreKit

/// A view that renders the highest-priority logo from the plugin registry.
struct LogoView: View {
    var scene: LogoScene = .general

    @ObservedObject private var logoRegistry = LumiCore.logoRegistry

    var body: some View {
        if let item = logoRegistry.bestItem {
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
