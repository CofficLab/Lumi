import SwiftUI

/// 流式阶段助手消息：仅渲染纯文本，避免高频 Markdown 解析。
struct StreamingAssistantRowView: View {
    let message: ChatMessage
    private let maxVisibleChars = 6_000

    private var visibleContent: String {
        let content = message.content
        guard content.count > maxVisibleChars else { return content }
        let tail = String(content.suffix(maxVisibleChars))
        return "...\n" + tail
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            MessageHeaderView {
                HStack(alignment: .center, spacing: 4) {
                    Text("Lumi")
                        .font(DesignTokens.Typography.caption1)
                        .fontWeight(.medium)
                        .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                    Text("·")
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    Text("生成中")
                        .font(DesignTokens.Typography.caption2)
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                }
            } trailing: {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            Text(verbatim: visibleContent)
                .font(.system(.body, design: .default))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .messageBubbleStyle(role: message.role, isError: message.isError)
        }
    }
}
