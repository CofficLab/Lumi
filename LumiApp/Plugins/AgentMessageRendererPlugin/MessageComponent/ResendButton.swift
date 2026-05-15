import SwiftUI
import LumiUI

/// 重发按钮组件
struct ResendButton: View {
    let action: () -> Void

    var body: some View {
        AppIconButton(
            systemImage: "arrow.clockwise",
            label: "重发",
            tint: Color.adaptive(light: "6B6B7B", dark: "EBEBF5").opacity(0.8),
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
