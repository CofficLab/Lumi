import LumiKernel
import LumiUI
import SwiftUI

/// 会话列表服务不可用时的错误按钮
///
/// 当 ChatService 无法获取时，点击按钮显示错误弹窗提示用户。
public struct ConversationListErrorButton: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    @State private var showErrorPopover = false

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            AppIconButton(
                systemImage: "message.fill",
                label: LumiPluginLocalization.string("会话列表", bundle: .module)
            ) {
                showErrorPopover.toggle()
            }
            .popover(isPresented: $showErrorPopover, arrowEdge: .bottom) {
                errorContentView
            }

            // 显示一个小的错误指示器
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 8))
                .foregroundColor(.red)
                .offset(x: 4, y: -4)
        }
    }

    private var errorContentView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.appTitle)
                .foregroundColor(.red)

            Text(LumiPluginLocalization.string("Service unavailable", bundle: .module))
                .font(.appBody)
                .foregroundColor(theme.textPrimary)

            Text(LumiPluginLocalization.string("Unable to load conversations", bundle: .module))
                .font(.appMicro)
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)

            Text(LumiPluginLocalization.string("Please restart the app", bundle: .module))
                .font(.appMicro)
                .foregroundColor(theme.textTertiary)
        }
        .padding(20)
        .frame(width: 240)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Error Button") {
    ConversationListErrorButton()
        .padding()
}
#endif
