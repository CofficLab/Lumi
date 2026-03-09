import MagicKit
import OSLog
import SwiftUI

/// 聊天消息列表视图 - 可滚动的聊天历史记录
struct ChatMessagesView: View, SuperLog {
    /// 日志标识 emoji
    nonisolated static let emoji = "💬"
    /// 是否输出详细日志
    nonisolated static let verbose = true

    /// 消息管理 ViewModel
    @EnvironmentObject var messageViewModel: MessageViewModel
    /// 会话管理 ViewModel
    @EnvironmentObject var conversationViewModel: ConversationViewModel
    /// 智能体提供者
    @EnvironmentObject var agentProvider: AgentProvider
    /// 处理状态 ViewModel
    @EnvironmentObject var processingStateViewModel: ProcessingStateViewModel
    /// 权限请求 ViewModel
    @EnvironmentObject var permissionRequestViewModel: PermissionRequestViewModel

    /// 非系统消息
    private var nonSystemMessages: [ChatMessage] {
        messageViewModel.messages.filter { $0.role != .system }
    }

    private struct DisplayMessageItem: Identifiable {
        let message: ChatMessage
        let relatedToolOutputs: [ChatMessage]

        var id: UUID { message.id }
    }

    /// UI 渲染层分组：将工具输出并入最近的 assistant tool-calls 消息
    /// 注意：这只影响展示，不改变底层消息列表和 LLM 通信数据。
    private var displayMessages: [DisplayMessageItem] {
        var items: [DisplayMessageItem] = []
        var index = 0

        while index < nonSystemMessages.count {
            let message = nonSystemMessages[index]

            if message.role == .assistant,
               let toolCalls = message.toolCalls,
               !toolCalls.isEmpty {
                let toolCallIDs = Set(toolCalls.map(\.id))
                var groupedOutputs: [ChatMessage] = []
                var cursor = index + 1

                while cursor < nonSystemMessages.count {
                    let next = nonSystemMessages[cursor]
                    guard let toolCallID = next.toolCallID else { break }
                    guard toolCallIDs.contains(toolCallID) else { break }
                    groupedOutputs.append(next)
                    cursor += 1
                }

                items.append(
                    DisplayMessageItem(
                        message: message,
                        relatedToolOutputs: groupedOutputs
                    )
                )
                index = cursor
                continue
            }

            // 无法归属到 assistant tool-call 的工具输出，仍按独立消息显示，避免信息丢失
            items.append(DisplayMessageItem(message: message, relatedToolOutputs: []))
            index += 1
        }

        return items
    }

    /// 是否已选择会话
    private var hasSelectedConversation: Bool {
        conversationViewModel.selectedConversationId != nil
    }

    /// 消息是否为空
    private var isMessagesEmpty: Bool {
        nonSystemMessages.isEmpty
    }

    var body: some View {
        Group {
            if hasSelectedConversation {
                if isMessagesEmpty {
                    emptyMessagesView
                } else {
                    messagesListView
                }
            } else {
                emptyStateView
            }
        }
        .background(.background.opacity(0.8))
        .onChange(of: conversationViewModel.selectedConversationId, handleConversationSelected)
    }
}

// MARK: - Subviews

extension ChatMessagesView {
    /// 消息列表视图
    private var messagesListView: some View {
        let items = displayMessages
        return ScrollViewReader { proxy in
            messageScrollContent(proxy: proxy, items: items)
        }
    }

    private func messageScrollContent(proxy: ScrollViewProxy, items: [DisplayMessageItem]) -> some View {
        ScrollView {
            messageRows(items: items)
        }
        .padding(.vertical)
        .onChange(of: nonSystemMessages.count) { oldCount, newCount in
            if newCount > oldCount {
                handleMessagesChanged(proxy: proxy)
            }
        }
        .overlay { messageOverlay }
    }

    private func messageRows(items: [DisplayMessageItem]) -> some View {
        let lastMessageID = items.last?.id
        return LazyVStack(alignment: .leading, spacing: 12) {
            // 加载更多历史消息按钮
            if messageViewModel.hasMoreMessages {
                loadMoreButton
            }

            ForEach(items) { item in
                ChatBubble(
                    message: item.message,
                    isLastMessage: item.id == lastMessageID,
                    relatedToolOutputs: item.relatedToolOutputs
                )
                .id(item.message.id)
            }
        }
        .padding(.horizontal)
    }

    /// 加载更多消息按钮
    private var loadMoreButton: some View {
        HStack {
            Spacer()

            Button(action: handleLoadMore) {
                HStack(spacing: 8) {
                    if messageViewModel.isLoadingMore {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.up.circle")
                    }

                    Text(loadMoreButtonText)
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)
            .disabled(messageViewModel.isLoadingMore)

            Spacer()
        }
        .padding(.vertical, 8)
    }

    /// 加载更多按钮文本
    private var loadMoreButtonText: String {
        if messageViewModel.isLoadingMore {
            return "加载中..."
        }
        let loaded = messageViewModel.messages.count
        let total = messageViewModel.totalMessageCount
        return "加载更早消息 (\(loaded)/\(total))"
    }

    private var messageOverlay: some View {
        VStack(spacing: 8) {
            DepthWarningBanner()

            if let request = permissionRequestViewModel.pendingPermissionRequest {
                PermissionRequestView(
                    request: request,
                    onAllow: {
                        agentProvider.respondToPermissionRequest(allowed: true)
                    },
                    onDeny: {
                        agentProvider.respondToPermissionRequest(allowed: false)
                    }
                )
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// 空状态视图 - 未选择会话时显示（无动态效果）
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            // 图标
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            // 标题
            Text("选择一个会话开始聊天", tableName: "DevAssistant")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            // 描述
            Text("从左侧列表选择一个现有会话，或创建新会话", tableName: "DevAssistant")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }

    /// 空消息视图 - 已选择会话但没有消息时显示（带动态效果）
    private var emptyMessagesView: some View {
        VStack(spacing: 20) {
            Spacer()

            // 图标
            Image(systemName: "text.bubble.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
            
            // 标题
            Text("暂无消息", tableName: "DevAssistant")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            // 描述
            Text("在下方输入框中输入您的问题，开始与 AI 助手对话", tableName: "DevAssistant")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}

// MARK: - Actions

extension ChatMessagesView {
    func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastMessage = displayMessages.last?.message else { return }

        Task {
            proxy.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }

    /// 智能滚动到底部
    /// 只在用户已经在底部附近时才自动滚动，避免打扰用户阅读历史消息
    func scrollToBottomIfNeeded(proxy: ScrollViewProxy) {
        guard let lastMessage = displayMessages.last?.message else { return }

        // 使用动画平滑滚动
        withAnimation(.easeOut(duration: 0.1)) {
            proxy.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }
}

// MARK: Event Handler

extension ChatMessagesView {
    func handleMessagesChanged(proxy: ScrollViewProxy) {
        if Self.verbose {
            os_log("\(self.t)📬 消息数量变化")
        }
    }

    func handleConversationSelected() {
        guard let conversationId = conversationViewModel.selectedConversationId else { return }

        if Self.verbose {
            os_log("\(self.t)✅ [\(conversationId)] 已选择")
        }
    }

    /// 处理加载更多历史消息
    func handleLoadMore() {
        guard let conversationId = conversationViewModel.selectedConversationId else { return }
        guard messageViewModel.hasMoreMessages, !messageViewModel.isLoadingMore else { return }

        if Self.verbose {
            os_log("\(self.t)📄 加载更多历史消息")
        }

        Task {
            await messageViewModel.loadMoreMessages(conversationId: conversationId)
        }
    }
}

// MARK: - Preview

#Preview("With Messages") {
    ChatMessagesView()
        .padding()
        .withDebugBar()
        .background(Color.black)
        .inRootView()
}

#Preview("Empty State") {
    ChatMessagesView()
        .padding()
        .withDebugBar()
        .background(Color.black)
        .inRootView()
}
