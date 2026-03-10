import MagicKit
import OSLog
import SwiftData
import SwiftUI

// MARK: - Input Events

/// 聊天消息列表视图 - 自己管理分页消息状态
struct ChatMessagesView: View, SuperLog {
    nonisolated static let emoji = "💬"
    nonisolated static let verbose = true
    nonisolated static let pageSize: Int = 20

    /// 会话管理 ViewModel
    @EnvironmentObject var conversationViewModel: ConversationViewModel

    /// SwiftData 模型上下文
    @Environment(\.modelContext) private var modelContext

    /// 智能体提供者
    @EnvironmentObject var agentProvider: AgentProvider

    /// 权限请求 ViewModel
    @EnvironmentObject var permissionRequestViewModel: PermissionRequestViewModel

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

    /// 当前选中的会话ID
    private var selectedConversationId: UUID? {
        conversationViewModel.selectedConversationId
    }

    /// 非系统消息
    private var nonSystemMessages: [ChatMessage] {
        messages.filter { $0.role != .system }
    }

    private struct DisplayMessageItem: Identifiable {
        let message: ChatMessage
        let relatedToolOutputs: [ChatMessage]
        var id: UUID { message.id }
    }

    /// UI 渲染层分组：将工具输出并入最近的 assistant tool-calls 消息
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

                items.append(DisplayMessageItem(message: message, relatedToolOutputs: groupedOutputs))
                index = cursor
                continue
            }

            items.append(DisplayMessageItem(message: message, relatedToolOutputs: []))
            index += 1
        }

        return items
    }

    /// 是否已选择会话
    private var hasSelectedConversation: Bool {
        selectedConversationId != nil
    }

    /// 消息是否为空
    private var isMessagesEmpty: Bool {
        nonSystemMessages.isEmpty
    }

    var body: some View {
        Group {
            if hasSelectedConversation {
                if isMessagesEmpty {
                    EmptyMessagesView()
                } else {
                    messagesListView
                }
            } else {
                EmptyStateView()
            }
        }
        .background(.background.opacity(0.8))
        .onChange(of: selectedConversationId, loadMessagesForSelectedConversation)
        // 监听用户消息已发出事件
        .onReceive(NotificationCenter.default.publisher(for: .userMessageSent)) { _ in }
        .onAppear(perform: self.handleOnAppear)
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
            messageRows(proxy: proxy, items: items)
        }
        .padding(.vertical)
        .overlay { messageOverlay }
    }

    private func messageRows(proxy: ScrollViewProxy, items: [DisplayMessageItem]) -> some View {
        let lastMessageID = items.last?.id
        return LazyVStack(alignment: .leading, spacing: 12) {
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

    private var messageOverlay: some View {
        VStack(spacing: 8) {
            DepthWarningBanner()
            if let request = permissionRequestViewModel.pendingPermissionRequest {
                PermissionRequestView(
                    request: request,
                    onAllow: { agentProvider.respondToPermissionRequest(allowed: true) },
                    onDeny: { agentProvider.respondToPermissionRequest(allowed: false) }
                )
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Message Loading

extension ChatMessagesView {
    /// 加载选中会话的消息（分页模式）
    private func loadMessagesForSelectedConversation() {
        guard let conversationId = selectedConversationId else {
            messages = []
            hasMoreMessages = false
            totalMessageCount = 0
            oldestLoadedTimestamp = nil
            return
        }

        if Self.verbose {
            os_log("\(Self.t)📥 [\(conversationId)] 开始加载消息（分页模式）")
        }

        Task {
            await loadMessagesPaginated(conversationId: conversationId)
        }
    }

    /// 分页加载消息（初始加载最近消息）
    private func loadMessagesPaginated(conversationId: UUID) async {
        // 重置分页状态
        oldestLoadedTimestamp = nil
        hasMoreMessages = false
        isLoadingMore = false

        // 获取消息总数
        totalMessageCount = await getMessageCount(forConversationId: conversationId)

        // 加载第一页（最近的消息）
        let result = await loadMessagesPage(
            forConversationId: conversationId,
            limit: Self.pageSize,
            beforeTimestamp: nil
        )

        await MainActor.run {
            messages = result.messages
            hasMoreMessages = result.hasMore

            // 更新最早加载的时间戳
            if let firstMessage = messages.first {
                oldestLoadedTimestamp = firstMessage.timestamp
            }

            if Self.verbose {
                os_log("\(Self.t)📄 [\(conversationId)] 分页加载完成: \(self.messages.count)/\(self.totalMessageCount) 条, hasMore: \(self.hasMoreMessages)")
            }
        }
    }

    /// 加载更多历史消息（上滑时调用）
    private func handleLoadMore() {
        guard let conversationId = selectedConversationId else { return }
        guard hasMoreMessages, !isLoadingMore else { return }

        if Self.verbose {
            os_log("\(Self.t)📄 加载更多历史消息")
        }

        Task {
            isLoadingMore = true
            defer { isLoadingMore = false }

            let result = await loadMessagesPage(
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
                    os_log("\(Self.t)📄 [\(conversationId)] 加载更多完成: \(self.messages.count)/\(self.totalMessageCount) 条, hasMore: \(self.hasMoreMessages)")
                }
            }
        }
    }

    /// 从 SwiftData 分页加载消息
    private func loadMessagesPage(
        forConversationId conversationId: UUID,
        limit: Int,
        beforeTimestamp: Date?
    ) async -> (messages: [ChatMessage], hasMore: Bool) {
        let descriptor = FetchDescriptor<Conversation>(
            predicate: #Predicate { conversation in
                conversation.id == conversationId
            }
        )

        guard let conversation = try? modelContext.fetch(descriptor).first else {
            return ([], false)
        }

        // 按时间倒序排列（最新的在前）
        let allMessages = conversation.messages
            .sorted { $0.timestamp > $1.timestamp }

        // 计算起始索引
        let startIndex: Int
        if let before = beforeTimestamp {
            // 找到时间戳早于 before 的第一条消息索引
            startIndex = allMessages.firstIndex { $0.timestamp < before } ?? allMessages.count
        } else {
            startIndex = 0
        }

        let endIndex = min(startIndex + limit, allMessages.count)

        guard endIndex > startIndex else {
            return ([], false)
        }

        // 提取分页数据
        let page = allMessages[startIndex..<endIndex]
        let hasMore = endIndex < allMessages.count

        // 转换回 ChatMessage 并恢复正序（最老的在前）
        let chatMessages = page.compactMap { $0.toChatMessage() }.reversed()

        return (Array(chatMessages), hasMore)
    }

    /// 获取消息总数
    private func getMessageCount(forConversationId conversationId: UUID) async -> Int {
        let descriptor = FetchDescriptor<Conversation>(
            predicate: #Predicate { conversation in
                conversation.id == conversationId
            }
        )
        return (try? modelContext.fetch(descriptor).first?.messages.count) ?? 0
    }
}

// MARK: - Event Handlers

extension ChatMessagesView {
    func handleOnAppear() {
        if Self.verbose {
            os_log("\(Self.t)👀 ChatMessagesView 出现，当前对话ID是：\(conversationViewModel.selectedConversationId?.uuidString ?? "")")
        }
        
        self.loadMessagesForSelectedConversation()
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
