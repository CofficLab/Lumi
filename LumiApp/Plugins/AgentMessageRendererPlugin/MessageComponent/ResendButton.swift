import SwiftUI
import LumiUI

/// 重发按钮组件
struct ResendButton: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    let action: () -> Void

    var body: some View {
        AppIconButton(
            systemImage: "arrow.clockwise",
            label: "重发",
            tint: theme.textSecondary.opacity(0.8),
            size: .compact,
            action: action
        )
        .help(String(localized: "重新发送该消息", table: "CoreMessageRenderer"))
    }
}

#Preview {
    ResendButton { }
        .padding()
}
