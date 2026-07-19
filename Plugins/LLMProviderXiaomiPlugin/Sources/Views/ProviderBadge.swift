import LumiKernel
import LumiUI
import SwiftUI

/// 错误消息顶部的供应商标签。
///
/// 根据错误消息的 `providerID` 显示对应供应商的短名（TokenPlan / 小米 API），
/// 让用户一眼看出错误来自哪个小米服务。
struct ProviderBadge: View {
    @LumiTheme private var theme

    let providerID: String

    private var shortName: String {
        switch providerID {
        case "xiaomi-api":
            return LumiPluginLocalization.string("API", bundle: .module)
        default:
            return LumiPluginLocalization.string("TokenPlan", bundle: .module)
        }
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
