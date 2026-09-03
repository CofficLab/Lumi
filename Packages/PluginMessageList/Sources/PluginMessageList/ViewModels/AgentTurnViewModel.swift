import Foundation
import ProviderMessage
import ProviderMessageStreaming

struct AgentTurnMessageProjection: Equatable {
    var userMessages: [Message] = []
    var processMessages: [Message] = []
    var lastMessage: Message?
    /// 会话当前活动的独立尾部提示，不参与"过程/结果"的折叠规则。
    var activityMessage: Message?
}

/// 单个 AgentTurnView 的消息数据源。它只接收 Turn 身份，自行读取、监听和投影消息。
@MainActor
final class AgentTurnViewModel: ObservableObject {
    @Published private(set) var projection = AgentTurnMessageProjection()

    private let services: MessageListServices
    private var item: AgentTurnPresentationItem
    private var refreshSequence: UInt64 = 0

    init(services: MessageListServices, item: AgentTurnPresentationItem) {
        self.services = services
        self.item = item
    }

    func activate() async {
        await refresh()
    }

    /// SwiftUI 会为相同 turnID 保留 StateObject；TurnRecord 状态变化时更新描述，
    /// 再由本 ViewModel 重新读取消息，而不是依赖外层重建视图。
    func update(item: AgentTurnPresentationItem) async {
        guard self.item != item else { return }
        self.item = item
        await refresh()
    }

    /// 停止当前回合尚未结束的全部 Tool Job。
    ///
    /// 取消是同步发起的状态操作，实际进程终止和终态事件仍由 ToolManager 负责。
    func stopCurrentTurn() {
        guard let turnID = item.record?.id else { return }
        services.toolManager?.cancelJobs(forTurnID: turnID)
    }

    func refresh() async {
        guard let messageManager = services.messages else {
            projection = AgentTurnMessageProjection()
            return
        }
        refreshSequence &+= 1
        let sequence = refreshSequence
        let conversationID = item.conversationID
        let messages = await messageManager.messagesSnapshot(in: conversationID)
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
        messages: [Message],
        streamingMessage: Message?,
        streamingStage: MessageStreamingStage = .idle
    ) -> AgentTurnMessageProjection {
        let chronological = messages.sorted(by: messageOrdering)
        let transientStatus = item.acceptsLiveActivity
            ? chronological.last(where: isTransientStatus)
            : nil
        let userMessages: [Message]
        var responseMessages: [Message]

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
        userMessages: [Message],
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

    private func currentStreamingMessage() -> Message? {
        guard item.acceptsLiveActivity, let streaming = services.streaming else { return nil }
        let stage = streaming.stage(for: item.conversationID)
        guard stage == .thinking || stage == .generating else { return nil }
        return streaming.streamingMessage(for: item.conversationID)
    }

    private func currentStreamingStage() -> MessageStreamingStage {
        guard item.acceptsLiveActivity, let streaming = services.streaming else { return .idle }
        return streaming.stage(for: item.conversationID)
    }

    private nonisolated static func activityMessage(
        item: AgentTurnPresentationItem,
        status: Message?,
        stage: MessageStreamingStage
    ) -> Message? {
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
        return Message(
            id: activityMessageID(for: item.id),
            conversationID: item.conversationID,
            role: .status,
            content: content,
            createdAt: status?.createdAt ?? item.record?.startedAt ?? .now,
            turnID: item.record?.id,
            metadata: ["isTransientStatus": "true"]
        )
    }

    private nonisolated static func isTransientStatus(_ message: Message) -> Bool {
        message.role == .status
            && (message.turnID == nil || message.metadata["isTransientStatus"] == "true")
    }

    private nonisolated static func isPlaceholderStatus(_ message: Message) -> Bool {
        message.role == .status && message.content == "…"
    }

    private nonisolated static func activityMessageID(for turnID: UUID) -> UUID {
        var bytes = turnID.uuid
        // XOR 保证动态行 ID 与 Turn ID 不同，同时保持一一映射和跨刷新稳定。
        bytes.1 ^= 0x40
        return UUID(uuid: bytes)
    }

    private nonisolated static func deduplicated(_ messages: [Message]) -> [Message] {
        var seen: Set<UUID> = []
        return messages.filter { seen.insert($0.id).inserted }
    }
}
