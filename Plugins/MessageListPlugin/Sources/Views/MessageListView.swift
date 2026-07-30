import LumiKernel
import LumiUI
import SwiftUI

/// Message List View
///
/// Displays the chat message list for the selected conversation.
struct MessageListView: View {
    @ObservedObject var kernel: LumiKernel

    @LumiTheme private var theme
    @State private var messages: [LumiChatMessage] = []
    @State private var showRawMessage = false
    @State private var isLoading = true

    private var selectedConversationID: UUID? {
        kernel.conversations?.selectedConversationID
    }

    var body: some View {
        Group {
            if isLoading {
                MessageLoadingView()
            } else if messages.isEmpty {
                MessageEmptyStateView()
            } else {
                messageScrollView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.surface)
        .task(id: selectedConversationID) {
            // 切换会话:进入 loading → 同步拉取数据 → 结束 loading。
            loadMessages(showLoading: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: .lumiMessagesDidChange)) { notification in
            guard let conversationID = selectedConversationID else { return }
            // 消息变更通知携带会话 ID 时只响应当前会话；为 nil 则视为全局刷新。
            if let changedID = notification.lumiConversationID, changedID != conversationID {
                return
            }
            // 流式刷新:静默更新数据,不触发 loading 以免闪烁。
            loadMessages(showLoading: false)
        }
    }

    private var messageScrollView: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(messages) { message in
                    MessageRowView(
                        message: message,
                        renderer: kernel.messageRendererManager?.renderer(for: message),
                        showRawMessage: $showRawMessage
                    )
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                }
            }
            .padding(.vertical, 4)
        }
    }

    /// 拉取当前会话的消息。
    ///
    /// - Parameter showLoading: 切换会话时传 `true` 包裹 loading 状态;
    ///   消息变更通知触发的流式刷新传 `false`,静默更新以免闪烁。
    private func loadMessages(showLoading: Bool) {
        if showLoading {
            isLoading = true
        }
        guard let conversationID = selectedConversationID else {
            messages = []
            isLoading = false
            return
        }
        messages = kernel.messageManager?.displayMessages(for: conversationID) ?? []
        isLoading = false
    }
}
