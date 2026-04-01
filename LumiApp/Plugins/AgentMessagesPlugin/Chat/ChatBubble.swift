import SwiftUI

// MARK: - Chat Bubble

/// 聊天气泡组件，用于显示用户消息、助手回复和工具输出
///
/// **新架构**：通过 MessageRendererVM 获取渲染视图，不再硬编码判断消息类型。
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
        HStack(alignment: .top, spacing: 8) {
            // MARK: - Avatar
            
            AvatarChatView(role: message.role, isToolOutput: message.isToolOutput)

            // MARK: - Content
            
            // 特殊情况：流式消息（UI 层特殊状态，不通过渲染器处理）
            if message.role == .assistant && isStreaming {
                StreamingAssistantRowView(message: message)
                    .messageBubbleStyle(role: message.role, isError: message.isError)
            } else {
                // 使用环境变量中的 VM 获取渲染视图（新架构）
                if let renderer = messageRendererVM.findRenderer(for: message) {
                    renderer.render(message: message, showRawMessage: $showRawMessage)
                } else {
                    // 兜底：如果没有匹配的渲染器，显示原始内容
                    fallbackView
                }
            }

            Spacer()
        }
    }
    
    // MARK: - Fallback View
    
    /// 兜底视图：当注册表中没有匹配的渲染器时使用
    private var fallbackView: some View {
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
