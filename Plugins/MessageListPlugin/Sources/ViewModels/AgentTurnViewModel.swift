import Combine
import Foundation
import KernelLumi

struct AgentTurnMessageProjection: Equatable {
    var userMessages: [LumiChatMessage] = []
    var processMessages: [LumiChatMessage] = []
    var lastMessage: LumiChatMessage?
    /// 会话当前活动的独立尾部提示，不参与“过程/结果”的折叠规则。
    var activityMessage: LumiChatMessage?
}

/// 单个 AgentTurnView 的消息数据源。它只接收 Turn 身份，自行读取、监听和投影消息。
@MainActor
final class AgentTurnViewModel: ObservableObject {
    @Published private(set) var projection = AgentTurnMessageProjection()

    private let kernel: KernelLumi
    private var item: AgentTurnPresentationItem
    private var cancellables: Set<AnyCancellable> = []
    private var didBindStreaming = false
    private var streamingRefreshTask: Task<Void, Never>?
    private var refreshSequence: UInt64 = 0

    init(kernel: KernelLumi, item: AgentTurnPresentationItem) {
        self.kernel = kernel
        self.item = item
        bindNotifications()
    }

    func activate() async {
        await refresh()
    }

    /// SwiftUI 会为相同 turnID 保留 StateObject；TurnRecord 状态变化时更新描述，
    /// 再由本 ViewModel 重新读取消息，而不是依赖外层重建视图。
    func update(item: AgentTurnPresentationItem) async {
        guard self.item != item else { return }
        self.item = item
        bindStreamingIfNeeded()
        await refresh()
    }

    func refresh() async {
        guard let messageManager = kernel.messageManager else {
            projection = AgentTurnMessageProjection()
            return
        }
        refreshSequence &+= 1
        let sequence = refreshSequence
        let conversationID = item.conversationID
        let messages = await Task.detached(priority: .userInitiated) {
            messageManager.messages(for: conversationID)
        }.value
        guard sequence == refreshSequence else { return }
        projection = Self.project(
            item: item,
            messages: messages,
            streamingMessage: currentStreamingMessage(),
            streamingStage: currentStreamingStage()
        )
    }

    nonisolated static func project(
        item: AgentTurnPresentationItem,
        messages: [LumiChatMessage],
        streamingMessage: LumiChatMessage?,
        streamingStage: ChatStage = .idle
    ) -> AgentTurnMessageProjection {
        let chronological = messages.sorted(by: messageOrdering)
        let transientStatus = item.acceptsLiveActivity
            ? chronological.last(where: isTransientStatus)
            : nil
        let userMessages: [LumiChatMessage]
        var responseMessages: [LumiChatMessage]

        if let record = item.record {
            let summary = AgentTurnSummaryBuilder()
                .build(records: [record], messages: chronological)
                .first
            userMessages = summary?.userMessage.map { [$0] } ?? []
            responseMessages = summary?.processMessages ?? []
            if let result = summary?.message,
               !(item.acceptsLiveActivity && isPlaceholderStatus(result)),
               !(result.role == .status && result.content == "…" && !responseMessages.isEmpty) {
                responseMessages.append(result)
            }
            if !item.acceptsLiveActivity {
                responseMessages.removeAll { $0.role == .status && $0.turnID == nil }
            }
        } else {
            userMessages = chronological.filter { $0.id == item.pendingAnchorMessageID }
            responseMessages = item.acceptsLiveActivity
                ? chronological.filter { $0.role == .status }
                : []
        }

        // V1 永不展示工具原始返回；工具调用本身仍在 assistant 消息中。
        responseMessages.removeAll { $0.role == .tool || $0.role == .user || $0.role == .system }
        // 瞬时 Status 是独立的尾部动态提示，不再混入过程或最终消息。
        responseMessages.removeAll(where: isTransientStatus)
        if let streamingMessage,
           item.acceptsLiveActivity,
           streamingMessage.conversationID == item.conversationID {
            responseMessages.append(streamingMessage)
        }
        responseMessages = deduplicated(responseMessages.sorted(by: messageOrdering))

        return AgentTurnMessageProjection(
            userMessages: userMessages,
            processMessages: Array(responseMessages.dropLast()),
            lastMessage: responseMessages.last,
            activityMessage: activityMessage(
                item: item,
                status: transientStatus,
                stage: streamingStage
            )
        )
    }

    nonisolated static func processDisclosureTitle(
        item: AgentTurnPresentationItem,
        userMessages: [LumiChatMessage],
        processCount: Int,
        now: Date
    ) -> String {
        let startedAt = item.record?.startedAt ?? userMessages.first?.createdAt ?? now
        let endedAt = item.record?.endedAt ?? now
        let elapsed = max(0, endedAt.timeIntervalSince(startedAt))
        return "耗时\(formattedDuration(elapsed)) \(processCount)条"
    }

    private nonisolated static func formattedDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration.rounded(.down))
        if totalSeconds < 60 {
            return "\(totalSeconds)秒"
        }
        let totalMinutes = totalSeconds / 60
        guard totalMinutes >= 60 else { return "\(totalMinutes)分钟" }
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return minutes == 0 ? "\(hours)小时" : "\(hours)小时\(minutes)分钟"
    }

    private func bindNotifications() {
        NotificationCenter.default.publisher(for: .lumiMessagesDidChange)
            .filter { [item] notification in
                MessageListNotificationFilter.shouldHandle(
                    eventConversationID: notification.lumiConversationID,
                    selectedConversationID: item.conversationID
                )
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in await self?.refresh() }
            }
            .store(in: &cancellables)

        bindStreamingIfNeeded()
    }

    private func bindStreamingIfNeeded() {
        guard !didBindStreaming,
              item.acceptsLiveActivity,
              let streaming = kernel.messageStreaming else { return }
        streaming.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.scheduleStreamingRefresh() }
            .store(in: &cancellables)
        didBindStreaming = true
    }

    private func scheduleStreamingRefresh() {
        guard streamingRefreshTask == nil else { return }
        streamingRefreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 16_000_000)
            guard !Task.isCancelled, let self else { return }
            self.streamingRefreshTask = nil
            await self.refresh()
        }
    }

    private func currentStreamingMessage() -> LumiChatMessage? {
        guard item.acceptsLiveActivity, let streaming = kernel.messageStreaming else { return nil }
        let stage = streaming.streamingStage(for: item.conversationID)
        guard stage == .thinking || stage == .generating else { return nil }
        return streaming.streamingRow(for: item.conversationID)
    }

    private func currentStreamingStage() -> ChatStage {
        guard item.acceptsLiveActivity, let streaming = kernel.messageStreaming else { return .idle }
        return streaming.streamingStage(for: item.conversationID)
    }

    private nonisolated static func activityMessage(
        item: AgentTurnPresentationItem,
        status: LumiChatMessage?,
        stage: ChatStage
    ) -> LumiChatMessage? {
        guard item.acceptsLiveActivity else { return nil }
        let content: String
        if let status, !status.content.isEmpty {
            content = status.content
        } else {
            switch stage {
            case .idle: return nil
            case .sending: content = "正在发送消息…"
            case .thinking: content = "正在思考…"
            case .generating: content = "正在生成回复…"
            }
        }
        return LumiChatMessage(
            id: activityMessageID(for: item.id),
            conversationID: item.conversationID,
            role: .status,
            content: content,
            turnID: item.record?.id,
            createdAt: status?.createdAt ?? item.record?.startedAt ?? .now,
            metadata: ["isTransientStatus": "true"]
        )
    }

    private nonisolated static func isTransientStatus(_ message: LumiChatMessage) -> Bool {
        message.role == .status
            && (message.turnID == nil || message.metadata["isTransientStatus"] == "true")
    }

    private nonisolated static func isPlaceholderStatus(_ message: LumiChatMessage) -> Bool {
        message.role == .status && message.content == "…"
    }

    private nonisolated static func activityMessageID(for turnID: UUID) -> UUID {
        var bytes = turnID.uuid
        // XOR 保证动态行 ID 与 Turn ID 不同，同时保持一一映射和跨刷新稳定。
        bytes.1 ^= 0x40
        return UUID(uuid: bytes)
    }

    private nonisolated static func deduplicated(_ messages: [LumiChatMessage]) -> [LumiChatMessage] {
        var seen: Set<UUID> = []
        return messages.filter { seen.insert($0.id).inserted }
    }

    private nonisolated static func messageOrdering(
        _ lhs: LumiChatMessage,
        _ rhs: LumiChatMessage
    ) -> Bool {
        if lhs.createdAt == rhs.createdAt { return lhs.id.uuidString < rhs.id.uuidString }
        return lhs.createdAt < rhs.createdAt
    }
}
