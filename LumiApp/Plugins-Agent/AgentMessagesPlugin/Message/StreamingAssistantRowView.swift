import SwiftUI

/// 流式阶段助手消息：仅渲染纯文本，避免高频 Markdown 解析。
struct StreamingAssistantRowView: View {
    let message: ChatMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 6) {
                Text("Lumi")
                    .font(DesignTokens.Typography.caption1)
                    .fontWeight(.medium)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                Text("生成中")
                    .font(DesignTokens.Typography.caption2)
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            Text(verbatim: message.content)
                .font(.system(.body, design: .default))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
        }
    }
}

