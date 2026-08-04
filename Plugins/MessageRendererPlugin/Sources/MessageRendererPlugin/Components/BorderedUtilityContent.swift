import LumiKernel
import LumiUI
import SwiftUI

/// 带边框的通用内容容器,按角色色调着色,用于 system/tool/error 等消息正文。
struct BorderedUtilityContent<Content: View>: View {
    let tint: Color
    let role: LumiChatMessageRole
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                tint.opacity(role == .system ? 0.07 : 0.1),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(tint.opacity(0.16), lineWidth: 1)
            )
    }
}
