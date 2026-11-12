import LumiUI
import ProviderConversation
import SwiftUI

struct MessageLoadingView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: ResponseVerbosity.standard.iconName)
                .font(.largeTitle)
                .foregroundStyle(theme.textSecondary)
                .opacity(0.55)

            VStack(spacing: 3) {
                Text(pluginLocalization.string("Loading messages…"))
                    .font(.system(size: 13, weight: .medium))
                Text(pluginLocalization.string("Standard mode"))
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .foregroundStyle(theme.textSecondary)
        .accessibilityElement(children: .combine)
        // 稳定标识符：供 UI 测试直接观测遮罩的存在与消失，
        // 而不必依赖「正在加载消息…」这类可能随文案变化的文案断言。
        .accessibilityIdentifier(MessageLoadingView.identifier)
    }
}

extension MessageLoadingView {
    /// 首屏遮罩的稳定标识符。
    static let identifier = "lumi.message-list.loading-mask"
}
