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
    nonisolated static let pageSize: Int = 50

    /// 智能体提供者
    @EnvironmentObject var agentProvider: AgentProvider

    /// 会话管理 ViewModel
    @EnvironmentObject var conversationViewModel: ConversationViewModel

    /// 处理状态 ViewModel（用于展示发送/等待首 token/生成中等状态）
    @EnvironmentObject var processingStateViewModel: ProcessingStateViewModel

    /// 当前显示的消息列表
    @State private var messages: [ChatMessage] = []

    /// 当前会话的临时状态消息 ID（不落库，仅用于 UI）
    @State private var transientStatusMessageId: UUID = UUID()

    /// 用户是否接近列表底部（用于决定是否自动滚动）
    @State private var isNearBottom: Bool = true

    /// 当用户不在底部时累积的“未读新消息”数量
    @State private var pendingNewMessageCount: Int = 0

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
        messages.filter { $0.role.shouldDisplayInChatList }
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
            GeometryReader { viewport in
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

                        // 底部哨兵：用于判断是否接近底部 & 精准滚动到底
                        GeometryReader { geo in
                            Color.clear
                                .preference(
                                    key: BottomSentinelMaxYKey.self,
                                    value: geo.frame(in: .named("messageScroll")).maxY
                                )
                        }
                        .frame(height: 0)
                        .id(BottomSentinelID.value)
                    }
                    .padding(.horizontal)
                }
                .coordinateSpace(name: "messageScroll")
                .padding(.vertical)
                .onAppear {
                    handleOnAppear(proxy: proxy)
                }
                .onPreferenceChange(BottomSentinelMaxYKey.self) { bottomMaxY in
                    // bottomMaxY 在 scroll 坐标空间内；viewport.size.height 是可视高度
                    // distanceToBottom 越小，越接近底部
                    let distanceToBottom = bottomMaxY - viewport.size.height
                    let near = distanceToBottom < 120
                    if near != isNearBottom {
                        isNearBottom = near
                        if near {
                            pendingNewMessageCount = 0
                        }
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if pendingNewMessageCount > 0, !isNearBottom {
                        Button {
                            pendingNewMessageCount = 0
                            scrollToBottom(animated: true)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.down.circle.fill")
                                Text("\(pendingNewMessageCount) 条新消息")
                                    .font(.caption)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 16)
                        .padding(.bottom, 16)
                    }
                }
            }
        }
        .onChange(of: selectedConversationId, handleConversationChanged)
        .onChange(of: processingStateViewModel.isProcessing) { _, _ in
            applyTransientStatusMessageIfNeeded()
        }
        .onChange(of: processingStateViewModel.statusText) { _, _ in
            applyTransientStatusMessageIfNeeded()
        }
        .onMessageSaved(perform: handleOnMessageSaved)
    }
}

// MARK: - Preference Keys

private enum BottomSentinelID {
    static let value = "MessageListView.BottomSentinel"
}

private struct BottomSentinelMaxYKey: PreferenceKey {
    static let defaultValue: CGFloat = .greatestFiniteMagnitude
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        // 取最大值，避免同一帧内多次更新触发警告
        value = max(value, nextValue())
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
        return "加载更早消息（已加载 \(messages.count) 条，共 \(totalMessageCount) 条）"
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
    private func applyTransientStatusMessageIfNeeded() {
        guard let _ = selectedConversationId else { return }

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
            messages = result.messages
            hasMoreMessages = result.hasMore

            // 更新最早加载的时间戳
            if let firstMessage = result.messages.first {
                oldestLoadedTimestamp = firstMessage.timestamp
            }

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

            // 加载下一页（早于当前最早的消息）
            let result = await agentProvider.loadMessagesPage(
                forConversationId: conversationId,
                limit: Self.pageSize,
                beforeTimestamp: oldestLoadedTimestamp
            )

            messages.insert(contentsOf: result.messages, at: 0)
            hasMoreMessages = result.hasMore

            if let firstMessage = result.messages.first {
                oldestLoadedTimestamp = firstMessage.timestamp
            }

            if Self.verbose {
                os_log("\(Self.t)📄 [\(conversationId)] 加载更多完成：\(self.messages.count)/\(self.totalMessageCount) 条，hasMore: \(self.hasMoreMessages)")
            }
        }
    }
}

// MARK: - Action

extension MessageListView {
    /// 滚动到底部
    func scrollToBottom(animated: Bool = true) {
        let action = {
            scrollProxy?.scrollTo(BottomSentinelID.value, anchor: .bottom)
        }

        if animated {
            withAnimation(.easeOut(duration: 0.3)) { action() }
        } else {
            action()
        }

        if Self.verbose {
            os_log("\(Self.t)📜 滚动到底部")
        }
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
            let existingIndex = messages.firstIndex { $0.id == message.id }
            let isNewMessage = existingIndex == nil

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

            // 自动滚动策略：只有用户接近底部时才自动到底
            if isNearBottom {
                scrollToBottom(animated: true)
            } else if isNewMessage {
                pendingNewMessageCount += 1
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
