import LumiKernel
import LumiUI
import MarkdownKit
import SuperLogKit
import SwiftUI
import os

/// Message List View
///
/// Displays the chat message list for the selected conversation.
struct MessageListView: View, SuperLog {
    @ObservedObject var kernel: LumiKernel

    @LumiTheme private var theme
    @State private var messages: [LumiChatMessage] = []
    @State private var paging = MessageListPagingState()
    @State private var hasEarlierMessages = false
    @State private var hasSelectedConversation = false
    @State private var showRawMessage = false
    /// 当前会话的 verbosity，注入到消息视图环境，使已有消息的渲染（如 header 显隐）随详细程度即时变化。
    @State private var verbosity: LumiResponseVerbosity = .standard

    private let messagePageSize = 10
    private static let bottomAnchorID = "message-list-bottom"

    private var isEmpty: Bool {
        messages.isEmpty && !isSending
    }

    private var isSending: Bool {
        kernel.messageSender?.isSending(for: selectedConversationID) ?? false
    }

    /// Display messages with a transient status message appended when sending.
    /// 工具调用结果消息的过滤已在 MessageManager.messages(for:) 中完成。
    private var displayMessages: [LumiChatMessage] {
        guard let conversationID = kernel.conversations?.selectedConversationID else {
            return messages
        }
        if isSending {
            let statusMessage = LumiChatMessage(
                conversationID: conversationID,
                role: .status,
                content: "正在发送消息…",
                metadata: ["isTransientStatus": "true"]
            )
            return messages + [statusMessage]
        }
        return messages
    }

    private var selectedConversationID: UUID? {
        kernel.conversations?.selectedConversationID
    }

    /// 当前会话应使用的 verbosity（取自会话管理器，缺失时回退默认级别）。
    private var sourceVerbosity: LumiResponseVerbosity {
        kernel.conversations?.verbosity(for: selectedConversationID) ?? .standard
    }

    /// 将当前会话的 verbosity 同步到本地状态，驱动消息视图环境重新注入。
    private func syncVerbosity() {
        verbosity = sourceVerbosity
    }

    // MARK: - SuperLog

    nonisolated public static let emoji = "💬"
    nonisolated(unsafe) public static var verbose = false
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "message-list.view")

    var body: some View {
        VStack(spacing: 0) {
            if kernel.messageRendererManager == nil {
                MessageRendererUnavailableView()
            } else if isEmpty && hasSelectedConversation {
                MessageEmptyStateView()
            } else if !hasSelectedConversation {
                MessageNoConversationView()
            } else {
                messageListView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.surface)
        // 将加载绑定到视图生命周期,而不是手动管理 Task;
        // task 会在视图消失时被自动取消,在 selectedConversationID 变化时重启。
        .task(id: selectedConversationID) {
            if Self.verbose {
                Self.logger.info("\(Self.t)MessageListView task start ➡️ selectedConversationID=\(selectedConversationID?.uuidString.prefix(8) ?? "nil"), isSending=\(isSending), localMessages=\(messages.count)")
            }
            syncVerbosity()
            paging.resetForConversationChange()
            await loadMessagesAsync()
            if Self.verbose {
                Self.logger.info("\(Self.t)MessageListView task finished ➡️ localMessages=\(messages.count), displayMessages=\(displayMessages.count)")
            }
        }
        .onChange(of: isSending) { _, newValue in
            if Self.verbose {
                Self.logger.info("\(Self.t)isSending changed ➡️ \(newValue), selectedConversationID=\(selectedConversationID?.uuidString.prefix(8) ?? "nil"), localMessages=\(messages.count), displayMessages=\(displayMessages.count)")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .lumiMessagesDidChange)) { _ in
            guard paging.shouldAutoRefreshLatestOnMessageChange else { return }
            if Self.verbose {
                Self.logger.info("\(Self.t)Messages changed notification received ➡️ selectedConversationID=\(selectedConversationID?.uuidString.prefix(8) ?? "nil"), isSending=\(isSending), localMessages=\(messages.count), displayMessages=\(displayMessages.count), followsLatest=\(paging.shouldAutoRefreshLatestOnMessageChange)")
            }
            loadMessages()
        }
        .onReceive(NotificationCenter.default.publisher(for: .lumiConversationsDidChange)) { _ in
            // 会话元数据（含 verbosity）变化：重新注入 verbosity 环境并重新加载消息，
            // 使工具消息的显隐与已有消息的渲染随详细程度即时更新。
            if Self.verbose {
                Self.logger.info("\(Self.t)Conversations changed notification received ➡️ selectedConversationID=\(selectedConversationID?.uuidString.prefix(8) ?? "nil"), verbosity=\(sourceVerbosity.rawValue)")
            }
            syncVerbosity()
            loadMessages()
        }
        .environment(\.lumiResponseVerbosity, verbosity)
    }

    private var messageListView: some View {
        ScrollViewReader { proxy in
            List {
                if hasEarlierMessages {
                    Button(action: loadEarlierMessages) {
                        Text("Load earlier messages")
                            .font(.appCaption)
                            .foregroundColor(theme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                    .listRowSeparator(.hidden)
                }

                ForEach(displayMessages) { message in
                    MessageRowView(
                        message: message,
                        renderer: kernel.messageRendererManager?.renderer(for: message),
                        showRawMessage: $showRawMessage
                    )
                    .id(message.id)
                    .padding(.horizontal, ChatMessageListLayout.messageRowHorizontalPadding)
                    .padding(.vertical, ChatMessageListLayout.messageRowVerticalPadding)
                    .listRowInsets(ChatMessageListLayout.messageRowInsets)
                    .listRowSeparator(.hidden)
                }

                bottomAnchor
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.preferOuterScroll, ChatMessageListLayout.prefersOuterScrollForMarkdown)
            // 切换会话后,等消息加载完成再滚到底部;
            // 在滚动之前给 List 一帧的渲染时间,避免 scrollTo 抢在布局前执行。
            .task(id: selectedConversationID) {
                await waitForMessagesReady()
                if Self.verbose {
                    Self.logger.info("\(Self.t)messageListView task finished, scroll to bottom ➡️ messages=\(messages.count), displayMessages=\(displayMessages.count)")
                }
                scrollToBottom(proxy: proxy, animated: false)
            }
            // 兜底:消息从空变成非空(初次进入 / 异步加载完成)时,确保滚动到底部。
            // 这是上面 .task 在 messages 尚未加载时早退的安全网。
            .onChange(of: messages.count) { oldCount, newCount in
                guard oldCount == 0, newCount > 0 else { return }
                if Self.verbose {
                    Self.logger.info("\(Self.t)messages loaded from empty, scroll to bottom ➡️ oldCount=\(oldCount), newCount=\(newCount)")
                }
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 50_000_000) // 50ms,让 List 完成第一轮布局
                    scrollToBottom(proxy: proxy, animated: false)
                }
            }
            .onChange(of: displayMessages.last?.id) { oldID, newID in
                // 1) 用户刚刚发送消息时(末尾是 `.user`) → 强制滚动到底部;
                // 2) 流式追加 assistant token 时,如果用户仍在"跟随最新"状态,也滚到底部,
                //    但仅在末尾消息从无到有时触发,避免每 token 一次抖动。
                guard oldID != newID, let last = displayMessages.last else { return }
                if last.role == .user {
                    if Self.verbose {
                        Self.logger.info("\(Self.t)user message detected, scroll to bottom")
                    }
                    scrollToBottom(proxy: proxy, animated: true)
                } else if paging.shouldAutoRefreshLatestOnMessageChange, last.role == .assistant {
                    if Self.verbose {
                        Self.logger.info("\(Self.t)assistant message appended, scroll to bottom")
                    }
                    scrollToBottom(proxy: proxy, animated: false)
                }
            }
        }
    }

    /// 等待本地消息列表从空变成非空(或超时)。
    ///
    /// 解决"视图出现时 messages 还没加载好,导致 scrollToBottom 被 guard 挡掉"的竞态。
    /// 给到 1s 上限,足以覆盖正常的 store 读取;超时后 scrollToBottom 内的 guard 仍然会生效,只是不强求滚动。
    private func waitForMessagesReady() async {
        let deadline = Date().addingTimeInterval(1.0)
        while messages.isEmpty, Date() < deadline {
            try? await Task.sleep(nanoseconds: 30_000_000) // 30ms
        }
    }

    /// 将消息列表滚动到最底部。
    ///
    /// - Parameter proxy: `ScrollViewReader` 提供的滚动代理。
    /// - Parameter animated: 是否使用动画。首次定位建议关闭动画以避免初次闪烁；
    ///   用户发送消息触发的滚动开启动画，过渡更自然。
    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool = true) {
        guard !displayMessages.isEmpty else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(Self.bottomAnchorID, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(Self.bottomAnchorID, anchor: .bottom)
        }
    }

    private var bottomAnchor: some View {
        Color.clear
            .frame(height: 1)
            .id(Self.bottomAnchorID)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .accessibilityHidden(true)
    }

    private func loadEarlierMessages() {
        Task { await loadEarlierMessagesAsync() }
    }

    private func loadMessages() {
        Task { await loadMessagesAsync() }
    }

    @MainActor
    private func loadEarlierMessagesAsync() async {
        guard let conversationID = selectedConversationID else { return }
        guard let manager = kernel.messageManager else { return }

        if Self.verbose {
            Self.logger.info("\(Self.t)loadEarlierMessagesAsync ➡️ conversation=\(conversationID.uuidString.prefix(8))…, before=\(paging.oldestVisibleMessageID?.uuidString.prefix(8) ?? "nil"), localMessages=\(messages.count)")
        }

        let olderPage = await manager.visibleMessages(
            for: conversationID,
            limit: messagePageSize,
            beforeMessageID: paging.oldestVisibleMessageID
        )
        guard !olderPage.isEmpty else { return }

        messages = olderPage + messages
        paging.didLoadEarlierPage(firstMessageID: messages.first?.id)
        hasEarlierMessages = await manager.hasEarlierMessages(
            for: conversationID,
            beforeMessageID: paging.oldestVisibleMessageID
        )

        if Self.verbose {
            Self.logger.info("\(Self.t)loadEarlierMessagesAsync 完成 ➡️ conversation=\(conversationID.uuidString.prefix(8))…, loaded=\(olderPage.count), first=\(messages.first?.id.uuidString.prefix(8) ?? "nil"), last=\(messages.last?.id.uuidString.prefix(8) ?? "nil"), hasEarlier=\(hasEarlierMessages)")
        }
    }

    @MainActor
    private func loadMessagesAsync() async {
        guard let conversationID = selectedConversationID else {
            if Self.verbose {
                Self.logger.info("\(Self.t)No conversation selected, clearing messages")
            }
            messages = []
            hasSelectedConversation = false
            hasEarlierMessages = false
            return
        }
        hasSelectedConversation = true
        // 只加载当前窗口的一页消息,避免把整段历史一次性拉入内存。
        guard let manager = kernel.messageManager else {
            messages = []
            hasEarlierMessages = false
            return
        }

        let shouldFollowLatest = paging.shouldAutoRefreshLatestOnMessageChange
        if Self.verbose {
            Self.logger.info("\(Self.t)loadMessagesAsync 开始 ➡️ conversation=\(conversationID.uuidString.prefix(8))…, isSending=\(isSending), followLatest=\(shouldFollowLatest), localMessages=\(messages.count), currentFirst=\(messages.first?.id.uuidString.prefix(8) ?? "nil"), currentLast=\(messages.last?.id.uuidString.prefix(8) ?? "nil"), oldestVisible=\(paging.oldestVisibleMessageID?.uuidString.prefix(8) ?? "nil")")
        }

        // When we are following the latest page, prefer the in-memory cache from
        // MessageManager. This avoids a race where the UI refreshes on the
        // `messagesDidChange` notification before the async store write finishes.
        //
        // Once a user loads earlier messages, we keep using paged store reads to
        // preserve the "older history above, latest page below" behavior.
        let loaded: [LumiChatMessage]
        if shouldFollowLatest {
            loaded = manager.displayMessages(for: conversationID)
        } else {
            loaded = await manager.visibleMessages(
                for: conversationID,
                limit: messagePageSize,
                beforeMessageID: nil
            )
        }
        if Self.verbose {
            Self.logger.info("\(Self.t)loadMessagesAsync 拉取完成 ➡️ conversation=\(conversationID.uuidString.prefix(8))…, loaded=\(loaded.count), first=\(loaded.first?.id.uuidString.prefix(8) ?? "nil"), last=\(loaded.last?.id.uuidString.prefix(8) ?? "nil"), roles=\(loaded.map { $0.role.rawValue }.joined(separator: ","))")
        }
        messages = loaded
        paging.didLoadLatestPage(firstMessageID: loaded.first?.id)
        hasEarlierMessages = await manager.hasEarlierMessages(
            for: conversationID,
            beforeMessageID: paging.oldestVisibleMessageID
        )

        if Self.verbose {
            Self.logger.info("\(Self.t)loadMessagesAsync 状态更新完成 ➡️ conversation=\(conversationID.uuidString.prefix(8))…, localMessages=\(messages.count), first=\(messages.first?.id.uuidString.prefix(8) ?? "nil"), last=\(messages.last?.id.uuidString.prefix(8) ?? "nil"), hasEarlier=\(hasEarlierMessages)")
        }
    }
}
