import SwiftUI

/// 聊天气泡组件，用于显示用户消息、助手回复和工具输出
struct ChatBubble: View {
    /// 消息对象
    let message: ChatMessage
    /// 是否是最后一条消息
    let isLastMessage: Bool
    /// 与当前 assistant 工具调用关联的工具输出（仅用于 UI 分组展示）
    let relatedToolOutputs: [ChatMessage]
    /// 是否为当前正在流式生成的 assistant 消息
    let isStreaming: Bool

    @State private var showRawMessage: Bool = false
    @EnvironmentObject var messageRendererVM: MessageRendererVM

    /// 初始化
    /// - Parameters:
    ///   - message: 消息对象
    ///   - isLastMessage: 是否是最后一条消息
    ///   - relatedToolOutputs: 关联的工具输出
    init(
        message: ChatMessage,
        isLastMessage: Bool,
        relatedToolOutputs: [ChatMessage] = [],
        isStreaming: Bool = false
    ) {
        self.message = message
        self.isLastMessage = isLastMessage
        self.relatedToolOutputs = relatedToolOutputs
        self.isStreaming = isStreaming
    }

    var body: some View {
        ZStack {
            if let renderer = messageRendererVM.findRenderer(for: message) {
                renderer.render(message: message, showRawMessage: $showRawMessage)
            } else {
                // 兜底：如果没有匹配的渲染器，显示原始内容
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.content)
                        .font(.body)
                        .foregroundColor(.primary)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
}
