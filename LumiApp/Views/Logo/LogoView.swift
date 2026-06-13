import LumiCoreKit
import SwiftUI

struct LogoView: View {
    var scene: LogoScene = .general

    @ObservedObject private var logoRegistry = LogoRegistry.shared

    var body: some View {
        if let item = logoRegistry.bestItem {
            item.makeView(scene)
        } else {
            // Fallback: 如果没有插件提供 Logo，显示空视图
            Color.clear
                .frame(width: 32, height: 32)
        }
    }
}
