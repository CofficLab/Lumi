import MagicKit
import OSLog
import SwiftUI

/// 消息列表视图组件
/// 自治组件，自己管理消息加载和分页状态
struct MessageListView: View, SuperLog {
    /// 日志标识 emoji
    nonisolated static let emoji = "📜"
    /// 是否启用详细日志
    nonisolated static let verbose = true
    /// 分页大小：每页加载的消息数量
    nonisolated static let pageSize: Int = 50

    /// 智能体提供者
    @EnvironmentObject var agentProvider: AgentProvider

    /// 会话管理 ViewModel
    @EnvironmentObject var conversationViewModel: ConversationViewModel

    /// 当前显示的消息列表
    @State private var messages: [ChatMessage] = []

    /// 是否还有更多历史消息可加载
    @State private var hasMoreMessages: Bool = false

    /// 是否正在加载更多消息
    @State private var isLoadingMore: Bool = false

    /// 当前会话的消息总数
    @State private var totalMessageCount: Int = 0

    /// 最早加载的消息时间戳（用于分页游标）
    @State private var oldestLoadedTimestamp: Date?

    /// ScrollViewProxy 引用
    @State private var scrollProxy: ScrollViewProxy?

    /// 当前选中的会话 ID
    private var selectedConversationId: UUID? {
        conversationViewModel.selectedConversationId
    }

    /// 非系统消息
    private var nonSystemMessages: [ChatMessage] {
        messages.filter { $0.role != .system }
    }

    /// 显示消息项：包含消息和相关的工具输出
    private var displayItems: [DisplayMessageItem] {
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

                items.append(DisplayMessageItem(message: message, relatedToolOutputs: groupedOutputs))
                index = cursor
                continue
            }

            items.append(DisplayMessageItem(message: message, relatedToolOutputs: []))
            index += 1
        }

        return items
    }

    var body: some View {
        let items = displayItems
        let lastMessageID = items.last?.id

        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if hasMoreMessages {
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
            .padding(.vertical)
            .onAppear {
                handleOnAppear(proxy: proxy)
            }
        }
        .onChange(of: selectedConversationId, handleConversationChanged)
        .onMessageSaved(perform: handleOnMessageSaved)
    }
}

// MARK: - View

extension MessageListView {
    /// 加载更多消息按钮
    private var loadMoreButton: some View {
        HStack {
            Spacer()
            Button(action: handleLoadMore) {
                HStack(spacing: 8) {
                    if isLoadingMore {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.up.circle")
                    }
                    Text(loadMoreButtonText).font(.caption)
                }
                .foregroundStyle(.secondary)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)
            .disabled(isLoadingMore)
            Spacer()
        }
        .padding(.vertical, 8)
    }

    /// 加载更多按钮文本
    private var loadMoreButtonText: String {
        if isLoadingMore {
            return "加载中..."
        }
        return "加载更早消息 (\(messages.count)/\(totalMessageCount))"
    }

    /// 显示消息项：包含消息和相关的工具输出
    struct DisplayMessageItem: Identifiable {
        let message: ChatMessage
        let relatedToolOutputs: [ChatMessage]
        var id: UUID { message.id }
    }
}

// MARK: - Loading

extension MessageListView {
    /// 加载消息
    func loadMessages() async {
        guard let conversationId = selectedConversationId else {
            if Self.verbose {
                os_log("\(Self.t)⚠️ 没有选中的对话，跳过加载")
            }
            return
        }

        await MainActor.run {
            isLoadingMore = true
        }

        if Self.verbose {
            os_log("\(Self.t)📥 [\(conversationId)] 开始加载消息")
        }

        // 获取消息总数
        let count = await agentProvider.getMessageCount(forConversationId: conversationId)

        await MainActor.run {
            totalMessageCount = count
        }

        // 加载第一页（最新的消息）
        let result = await agentProvider.loadMessagesPage(
            forConversationId: conversationId,
            limit: Self.pageSize,
            beforeTimestamp: nil
        )

        await MainActor.run {
            messages = result.messages
            hasMoreMessages = result.hasMore
            isLoadingMore = false

            // 更新最早加载的时间戳
            if let firstMessage = result.messages.first {
                oldestLoadedTimestamp = firstMessage.timestamp
            }

            if Self.verbose {
                os_log("\(Self.t)✅ [\(conversationId)] 加载完成：\(self.messages.count)/\(self.totalMessageCount) 条，hasMore: \(self.hasMoreMessages)")
            }
        }
    }

    /// 加载更多历史消息
    func handleLoadMore() {
        guard hasMoreMessages, !isLoadingMore, let conversationId = selectedConversationId else { return }

        Task {
            await MainActor.run {
                isLoadingMore = true
            }

            if Self.verbose {
                os_log("\(Self.t)📄 [\(conversationId)] 加载更早消息...")
            }

            // 加载下一页（早于当前最早的消息）
            let result = await agentProvider.loadMessagesPage(
                forConversationId: conversationId,
                limit: Self.pageSize,
                beforeTimestamp: oldestLoadedTimestamp
            )

            await MainActor.run {
                messages.insert(contentsOf: result.messages, at: 0)
                hasMoreMessages = result.hasMore

                // 更新最早加载的时间戳
                if let firstMessage = result.messages.first {
                    oldestLoadedTimestamp = firstMessage.timestamp
                }

                if Self.verbose {
                    os_log("\(Self.t)📄 [\(conversationId)] 加载更多完成：\(self.messages.count)/\(self.totalMessageCount) 条，hasMore: \(self.hasMoreMessages)")
                }
            }
        }
    }
}

// MARK: - Action

extension MessageListView {
    /// 滚动到底部
    func scrollToBottom() {
//        guard let lastMessage = displayItems.last else { return }
//
//        withAnimation(.easeOut(duration: 0.3)) {
//            scrollProxy?.scrollTo(lastMessage.id, anchor: .bottom)
//        }
//
//        if Self.verbose {
//            os_log("\(Self.t)📜 滚动到底部：\(lastMessage.id)")
//        }
    }
}

// MARK: - Event Handlers

extension MessageListView {
    /// 处理视图出现事件
    /// - Parameter proxy: ScrollView 代理
    func handleOnAppear(proxy: ScrollViewProxy) {
        scrollProxy = proxy
        Task {
            await loadMessages()
        }
    }

    /// 处理会话变更事件
    func handleConversationChanged() {
        Task {
            await loadMessages()
        }
    }

    /// 处理消息保存事件
    /// - Parameter message: 已保存的消息
    func handleOnMessageSaved(message: ChatMessage) {
        Task {
            await loadMessages()
            self.scrollToBottom()
        }
    }
}

// MARK: - Preview

#Preview("MessageListView - Small") {
    MessageListView()
        .padding()
        .background(Color.black)
        .frame(width: 800, height: 600)
}

#Preview("MessageListView - Large") {
    MessageListView()
        .padding()
        .background(Color.black)
        .frame(width: 1200, height: 1200)
}
