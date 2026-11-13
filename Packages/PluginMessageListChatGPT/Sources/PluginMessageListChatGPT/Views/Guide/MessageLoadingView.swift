import LumiUI
import SwiftUI
import KitMessageList

/// V5（ChatGPT）首屏遮罩。
///
/// 只在首屏定位完成前显示；`InitialPositionGate` 的超时兜底保证它有确定上界。
struct MessageLoadingView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "message")
                .font(.largeTitle)
                .foregroundStyle(theme.textSecondary)
                .opacity(0.55)

            VStack(spacing: 3) {
                Text(pluginLocalization.string("正在加载消息…"))
                    .font(.system(size: 13, weight: .medium))
                Text(pluginLocalization.string("ChatGPT 风格消息列表"))
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .foregroundStyle(theme.textSecondary)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(pluginLocalization.string("正在加载消息…"))
    }
}
