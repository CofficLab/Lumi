import MagicKit
import OSLog
import SwiftUI

/// 消息列表视图组件
/// 自治组件，自己管理消息加载和分页状态
struct MessageListView: View, SuperLog {
    /// 日志标识 emoji
    nonisolated static let emoji = "📜"
    /// 是否启用详细日志
    nonisolated static let verbose = false
    /// 分页大小：每页加载的消息数量
    nonisolated static let pageSize: Int = 10

    /// 智能体提供者
    @EnvironmentObject var agentProvider: AgentVM

    /// 会话管理 ViewModel
    @EnvironmentObject var ConversationVM: ConversationVM

    /// 处理状态 ViewModel（用于展示发送/等待首 token/生成中等状态）
    @EnvironmentObject var processingStateViewModel: ProcessingStateVM

    /// 当前显示的消息列表
    @State private var messages: [ChatMessage] = []

    /// 当前会话的临时状态消息 ID（不落库，仅用于 UI）
    @State private var transientStatusMessageId: UUID = UUID()

    /// 是否还有更多历史消息可加载
    @State private var hasMoreMessages: Bool = false

    /// 是否正在加载更多消息
    @State private var isLoadingMore: Bool = false

    /// 当前会话的消息总数
    @State private var totalMessageCount: Int = 0

    /// 最早加载的消息时间戳（用于分页游标）
    @State private var oldestLoadedTimestamp: Date?

    /// 当前选中的会话 ID
    private var selectedConversationId: UUID? {
        ConversationVM.selectedConversationId
    }

    var body: some View {
        ScrollViewReader { proxy in
            let lastMessageID = messages.last?.id

            Group {
                if messages.isEmpty {
                    if isLoadingMore, selectedConversationId != nil {
                        loadingOverlay
                    } else {
                        EmptyMessagesView()
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            if hasMoreMessages {
                                loadMoreButton
                            }

                            ForEach(messages) { message in
                                ChatBubble(
                                    message: message,
                                    isLastMessage: message.id == lastMessageID,
                                    relatedToolOutputs: []
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    // 消息列表统一接管滚动，避免消息内部可滚动区域抢占滚轮造成卡顿感
                    .environment(\.preferOuterScroll, true)
                    .padding(.vertical)
                }
            }
            .onAppear(perform: handleOnAppear)
            .onChange(of: selectedConversationId, handleConversationChanged)
            .onChange(of: processingStateViewModel.isProcessing, applyTransientStatusMessageIfNeeded)
            .onChange(of: processingStateViewModel.statusText, applyTransientStatusMessageIfNeeded)
            .onMessageSaved(perform: handleOnMessageSaved)
            .onAgentInputDidSendMessage {
                handleUserDidSendMessageEvent(proxy: proxy)
            }
        }
    }
}

// MARK: - View

extension MessageListView {
    /// 首次加载时的简易 Loading 覆盖层
    private var loadingOverlay: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("正在加载历史消息…")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        return "加载更早消息（已加载 \(messages.count) 条，共 \(totalMessageCount) 条）"
    }
}

// MARK: - Loading

extension MessageListView {
    private func applyTransientStatusMessageIfNeeded() {
        guard selectedConversationId != nil else { return }

        if processingStateViewModel.isProcessing, !processingStateViewModel.statusText.isEmpty {
            let statusText = processingStateViewModel.statusText
            if let index = messages.firstIndex(where: { $0.id == transientStatusMessageId }) {
                var m = messages[index]
                m.content = statusText
                // 通过创建新数组触发 SwiftUI 更新
                var updated = messages
                updated[index] = m
                messages = updated
            } else {
                let m = ChatMessage(
                    id: transientStatusMessageId,
                    role: .status,
                    content: statusText,
                    timestamp: Date(),
                    isTransientStatus: true
                )
                messages.append(m)
            }
        } else {
            // 结束后移除临时状态消息
            if messages.contains(where: { $0.id == transientStatusMessageId }) {
                messages.removeAll { $0.id == transientStatusMessageId }
            }
        }
    }

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
        defer {
            Task { @MainActor in
                isLoadingMore = false
            }
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
            // oldestLoadedTimestamp 作为分页游标必须基于“原始页”，即使该页被过滤也要前进
            if let firstMessage = result.messages.first {
                oldestLoadedTimestamp = firstMessage.timestamp
            }

            messages = result.messages
            hasMoreMessages = result.hasMore

            if Self.verbose {
                os_log("\(Self.t)✅ [\(conversationId)] 加载完成：\(self.messages.count)/\(self.totalMessageCount) 条，hasMore: \(self.hasMoreMessages)")
            }
            // loadMessages 会覆盖本地数组，需要重新注入临时状态消息
            applyTransientStatusMessageIfNeeded()
        }
    }

    /// 加载更多历史消息
    func handleLoadMore() {
        guard hasMoreMessages, !isLoadingMore, let conversationId = selectedConversationId else { return }

        Task { @MainActor in
            isLoadingMore = true
            defer { isLoadingMore = false }

            if Self.verbose {
                os_log("\(Self.t)📄 [\(conversationId)] 加载更早消息...")
            }

            let result = await agentProvider.loadMessagesPage(
                forConversationId: conversationId,
                limit: Self.pageSize,
                beforeTimestamp: oldestLoadedTimestamp
            )

            if let firstMessage = result.messages.first {
                oldestLoadedTimestamp = firstMessage.timestamp
            }

            messages.insert(contentsOf: result.messages, at: 0)
            hasMoreMessages = result.hasMore

            if Self.verbose {
                os_log("\(Self.t)📄 [\(conversationId)] 加载更多完成：\(self.messages.count)/\(self.totalMessageCount) 条，hasMore: \(self.hasMoreMessages)")
            }
        }
    }
}

// MARK: - Event Handlers

extension MessageListView {
    /// 视图出现时加载消息
    func handleOnAppear() {
        Task { await loadMessages() }
    }

    /// 处理会话变更事件
    func handleConversationChanged() {
        Task {
            await MainActor.run {
                // 切换会话时，为临时状态消息生成新 ID，避免串会话
                transientStatusMessageId = UUID()
            }
            await loadMessages()
        }
    }

    /// 处理消息保存事件
    /// - Parameter message: 已保存的消息
    func handleOnMessageSaved(message: ChatMessage, conversationId: UUID) {
        // 仅处理当前会话，避免切换对话时“串话”
        guard conversationId == selectedConversationId else { return }

        Task { @MainActor in
            // ChatHistoryService 已下沉过滤规则；实时新增也要遵守
            guard message.shouldDisplayInChatList() else {
                // 如果之前插入过（旧版本/竞态），确保移除
                messages.removeAll { $0.id == message.id }
                return
            }

            let existingIndex = messages.firstIndex { $0.id == message.id }

            if let idx = existingIndex {
                messages[idx] = message
            } else {
                // 按时间戳插入，保持顺序稳定
                if let insertIndex = messages.firstIndex(where: { $0.timestamp > message.timestamp }) {
                    messages.insert(message, at: insertIndex)
                } else {
                    messages.append(message)
                }
            }

            // 更新分页游标信息（仅用于按钮文案/判断）
            totalMessageCount = max(totalMessageCount, messages.count)
            if let first = messages.first {
                oldestLoadedTimestamp = first.timestamp
            }
        }
    }

    /// 处理来自 AgentInput 插件的「用户发送新消息」事件（用于自动滚动到底部）
    /// - Parameter proxy: 用于控制滚动的 ScrollViewProxy
    func handleUserDidSendMessageEvent(proxy: ScrollViewProxy) {
        if Self.verbose {
            os_log("\(Self.t)📜 收到 AgentInput 用户发送消息事件，准备滚动到底部")
        }

        // 延迟一点时间，让新消息完成插入并刷新到本地 messages
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            guard let last = messages.last else {
                if Self.verbose {
                    os_log("\(Self.t)⚠️ 滚动失败：messages 为空")
                }
                return
            }
            if Self.verbose {
                os_log("\(Self.t)📜 滚动到最后一条用户消息：\(last.id.uuidString)")
            }
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
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
