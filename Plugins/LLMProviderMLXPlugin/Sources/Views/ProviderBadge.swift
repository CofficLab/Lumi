import LumiCoreKit
import LumiUI
import SwiftUI

/// 错误消息顶部的供应商标签。
///
/// MLX 供应商只有一个 provider id（`mlx`），固定显示「Local」以提示这是本地模型。
struct ProviderBadge: View {
    @LumiTheme private var theme

    let providerID: String

    private var shortName: String {
        LumiPluginLocalization.string("Local", bundle: .module)
    }

    var body: some View {
        Text(shortName)
            .font(.appMicro)
            .fontWeight(.semibold)
            .foregroundColor(theme.textSecondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(theme.textSecondary.opacity(0.14))
            )
            .overlay(
                Capsule()
                    .stroke(theme.textTertiary.opacity(0.25), lineWidth: 0.5)
            )
    }
}
