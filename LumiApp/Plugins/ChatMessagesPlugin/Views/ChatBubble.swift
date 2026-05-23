import LumiUI
import SwiftUI

/// 聊天气泡组件，用于显示用户消息、助手回复和工具输出
struct ChatBubble: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    /// 消息对象
    let message: ChatMessage
    /// 是否是最后一条消息
    let isLastMessage: Bool
    /// 与当前 assistant 工具调用关联的工具输出（仅用于 UI 分组展示）
    /// 是否为当前正在流式生成的 assistant 消息
    let isStreaming: Bool

    @State private var showRawMessage: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    @EnvironmentObject var messageRendererVM: AppMessageRendererVM
    @EnvironmentObject var timelineViewModel: WindowChatTimelineViewModel
    @EnvironmentObject private var inputQueueVM: WindowInputQueueVM

    /// 初始化
    /// - Parameters:
    ///   - message: 消息对象
    ///   - isLastMessage: 是否是最后一条消息
    init(
        message: ChatMessage,
        isLastMessage: Bool,
        isStreaming: Bool = false
    ) {
        self.message = message
        self.isLastMessage = isLastMessage
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
                        .font(.appBody)
                        .foregroundColor(theme.textPrimary)
                }
                .padding()
                .appSurface(style: .subtle, cornerRadius: 8)
            }
        }
        .contextMenu {
            if message.role == .user, !message.content.isEmpty {
                Button {
                    inputQueueVM.enqueueText(message.content)
                } label: {
                    Label(String(localized: "Resend", table: "AgentChat"), systemImage: "arrow.clockwise")
                }
            }

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label(String(localized: "Delete Message", table: "AgentChat"), systemImage: "trash")
            }
        }
        .alert(String(localized: "Delete Message", table: "AgentChat"), isPresented: $showDeleteConfirmation) {
            Button(String(localized: "Cancel", table: "AgentChat"), role: .cancel) {}
            Button(String(localized: "Delete", table: "AgentChat"), role: .destructive) {
                timelineViewModel.deleteMessage(message.id)
            }
        } message: {
            Text(String(localized: "Are you sure you want to delete this message? This action cannot be undone.", table: "AgentChat"))
        }
    }
}
