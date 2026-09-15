import SwiftUI

/// "BETA" 徽章：标记仍在打磨中的功能（如 V1 简洁模式）。
struct BetaBadgeView: View {
    var body: some View {
        Text(LumiPluginLocalization.string("BETA", bundle: .module))
            .font(.system(size: 8, weight: .bold))
            .tracking(0.4)
            .foregroundStyle(.white)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(Color.orange, in: Capsule())
    }
}
