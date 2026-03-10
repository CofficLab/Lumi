import MagicKit
import OSLog
import SwiftData
import SwiftUI

// MARK: - Input Events

/// 聊天消息列表视图组件
/// 自己管理分页消息状态，支持上滑加载更多历史消息
struct ChatMessagesView: View, SuperLog {
    /// 日志标识 emoji
    nonisolated static let emoji = "💬"
    /// 是否启用详细日志
    nonisolated static let verbose = true
    /// 分页大小：每页加载的消息数量
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

    /// 用于追踪是否已经自动滚动到底部（避免每次加载都滚动）
    @State private var hasAutoScrolledToBottom: Bool = false

    /// 当前选中的会话 ID
    private var selectedConversationId: UUID? {
        conversationViewModel.selectedConversationId
    }

    /// 非系统消息
    private var nonSystemMessages: [ChatMessage] {
        messages.filter { $0.role != .system }
    }

    /// 显示消息项：包含消息和相关的工具输出
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
        .onChange(of: selectedConversationId, handleConversationChanged)
        .onMessageSaved(perform: handleMessageSaved)
        .onAppear(perform: self.handleOnAppear)
    }

    /// 滚动到底部
    private func scrollToBottom() {
        guard let lastMessage = displayMessages.last else { return }

        withAnimation(.easeOut(duration: 0.3)) {
            NotificationCenter.default.post(
                name: .scrollToBottom,
                object: nil,
                userInfo: ["messageId": lastMessage.id]
            )
        }

        // 标记已滚动，避免下次加载历史消息时也滚动
        hasAutoScrolledToBottom = true

        if Self.verbose {
            os_log("\(Self.t)📜 滚动到底部：\(lastMessage.id)")
        }
    }
}

// MARK: - View

extension ChatMessagesView {
    /// 消息列表视图
    private var messagesListView: some View {
        let items = displayMessages
        return ScrollViewReader { proxy in
            messageScrollContent(proxy: proxy, items: items)
        }
    }

    /// 消息滚动内容视图
    /// - Parameters:
    ///   - proxy: 滚动代理
    ///   - items: 显示消息项列表
    private func messageScrollContent(proxy: ScrollViewProxy, items: [DisplayMessageItem]) -> some View {
        ScrollView {
            messageRows(proxy: proxy, items: items)
        }
        .padding(.vertical)
        .overlay { messageOverlay }
        .onReceive(NotificationCenter.default.publisher(for: .scrollToBottom)) { notification in
            // 监听滚动到底部通知
            if let messageId = notification.userInfo?["messageId"] as? UUID {
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo(messageId, anchor: .bottom)
                }
            }
        }
    }

    /// 消息行视图
    /// - Parameters:
    ///   - proxy: 滚动代理
    ///   - items: 显示消息项列表
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

    /// 消息叠加层视图：显示深度警告和权限请求
    private var messageOverlay: some View {
        VStack(spacing: 8) {
            DepthWarningBanner()
            if let request = permissionRequestViewModel.pendingPermissionRequest {
                PermissionRequestView(
                    request: request,
                    onAllow: { Task { await agentProvider.respondToPermissionRequest(allowed: true) } },
                    onDeny: { Task { await agentProvider.respondToPermissionRequest(allowed: false) } }
                )
            }
        }
        .padding()
    }
}

// MARK: - Loading

extension ChatMessagesView {
    /// 加载选中会话的消息
    func loadMessagesForSelectedConversation() async {
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
        let count = await getMessageCount(forConversationId: conversationId)

        await MainActor.run {
            totalMessageCount = count
        }

        // 加载第一页（最新的消息）
        let result = await loadMessagesPage(
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
                    os_log("\(Self.t)📄 [\(conversationId)] 加载更多完成：\(self.messages.count)/\(self.totalMessageCount) 条，hasMore: \(self.hasMoreMessages)")
                }
            }
        }
    }

    /// 从 SwiftData 分页加载消息
    /// - Parameters:
    ///   - conversationId: 会话 ID
    ///   - limit: 每页数量限制
    ///   - beforeTimestamp: 在此时间戳之前的消息
    /// - Returns: (消息列表，是否还有更多)
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
        let page = allMessages[startIndex ..< endIndex]
        let hasMore = endIndex < allMessages.count

        // 转换回 ChatMessage 并恢复正序（最老的在前）
        let chatMessages = page.compactMap { $0.toChatMessage() }.reversed()

        return (Array(chatMessages), hasMore)
    }

    /// 获取消息总数
    /// - Parameter conversationId: 会话 ID
    /// - Returns: 消息总数
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
    /// 处理视图出现事件
    @MainActor
    func handleOnAppear() {
        if Self.verbose {
            os_log("\(Self.t)👀 ChatMessagesView 出现，当前对话 ID 是：\(conversationViewModel.selectedConversationId?.uuidString ?? "")")
        }

        Task {
            await self.loadMessagesForSelectedConversation()
        }
    }

    /// 处理用户消息已保存事件
    /// - Parameter message: 已保存的用户消息
    @MainActor
    func handleMessageSaved(_ message: ChatMessage) {
        if Self.verbose {
            os_log("\(Self.t)✉️ [\(conversationViewModel.selectedConversationId?.uuidString ?? "")] 消息已保存，刷新消息列表")
        }

        Task {
            await self.loadMessagesForSelectedConversation()
        }
    }

    func handleConversationChanged() {
        Task {
            await loadMessagesForSelectedConversation()
        }
    }
}

// MARK: - Notification Name

extension Notification.Name {
    /// 滚动到底部通知
    static let scrollToBottom = Notification.Name("ChatMessagesView.scrollToBottom")
}

// MARK: - Preview

#Preview("ChatMessagesView - Small") {
    ChatMessagesView()
        .padding()
        .withDebugBar()
        .background(Color.black)
        .inRootView()
        .frame(width: 800, height: 600)
}

#Preview("ChatMessagesView - Large") {
    ChatMessagesView()
        .padding()
        .withDebugBar()
        .background(Color.black)
        .inRootView()
        .frame(width: 1200, height: 1200)
}
