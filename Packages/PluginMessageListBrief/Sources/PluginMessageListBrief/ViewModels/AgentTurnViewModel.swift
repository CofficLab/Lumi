import Foundation
import ProviderConversationState
import ProviderMessage
import ProviderMessageStreaming

struct AgentTurnMessageProjection: Equatable {
    var userMessages: [Message] = []
    var processMessages: [Message] = []
    var lastMessage: Message?
    /// 会话当前活动的独立尾部状态，不属于消息时间线。
    var activity: AgentActivityProjection?
}

/// 单个 AgentTurnView 的消息数据源。它只接收 Turn 身份，自行读取、监听和投影消息。
@MainActor
final class AgentTurnViewModel {
    enum Event {
        case projectionChanged(AgentTurnMessageProjection)
    }

    protocol ObserverHandle: AnyObject {
        func cancel()
    }

    private final class Handle: ObserverHandle {
        private let cancelAction: () -> Void
        private var isCancelled = false

        init(cancelAction: @escaping () -> Void) {
            self.cancelAction = cancelAction
        }

        func cancel() {
            guard !isCancelled else { return }
            isCancelled = true
            cancelAction()
        }
    }

    private(set) var projection = AgentTurnMessageProjection()

    private let services: MessageListServices
    private var item: AgentTurnPresentationItem
    private var refreshSequence: UInt64 = 0
    private var observers: [UUID: (Event) -> Void] = [:]

    init(services: MessageListServices, item: AgentTurnPresentationItem) {
        self.services = services
        self.item = item
    }

    @discardableResult
    func addObserver(_ callback: @escaping (Event) -> Void) -> any ObserverHandle {
        let id = UUID()
        observers[id] = callback
        return Handle { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }

    func activate() async {
        await refresh()
    }

    /// 视图会为相同 turnID 保留同一 ViewModel；TurnRecord 状态变化时更新描述，
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
            setProjection(AgentTurnMessageProjection())
            return
        }
        refreshSequence &+= 1
        let sequence = refreshSequence
        let conversationID = item.conversationID
        let messages = await messageManager.messagesSnapshot(in: conversationID)
        guard sequence == refreshSequence else { return }
        let nextProjection = Self.project(
            item: item,
            messages: messages,
            conversationState: services.conversationState?.state(for: conversationID),
            streamingStage: currentStreamingStage()
        )
        setProjection(nextProjection)
    }

    private func setProjection(_ nextProjection: AgentTurnMessageProjection) {
        guard nextProjection != projection else { return }
        projection = nextProjection
        notify(.projectionChanged(nextProjection))
    }

    private func notify(_ event: Event) {
        for callback in Array(observers.values) {
            callback(event)
        }
    }

    nonisolated static func project(
        item: AgentTurnPresentationItem,
        messages: [Message],
        conversationState: ConversationStateSnapshot?,
        streamingStage: MessageStreamingStage = .idle
    ) -> AgentTurnMessageProjection {
        let chronological = messages.sorted(by: messageOrdering)
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
        // V1 不将流式临时回复加入投影；仅在回合结束后展示完整落库消息。
        responseMessages = deduplicated(responseMessages.sorted(by: messageOrdering))

        return AgentTurnMessageProjection(
            userMessages: userMessages,
            processMessages: Array(responseMessages.dropLast()),
            lastMessage: responseMessages.last,
            activity: item.acceptsLiveActivity
                ? AgentActivityProjection.resolve(
                    conversationState: conversationState,
                    streamingStage: streamingStage
                )
                : nil
        )
    }

    nonisolated static func processDisclosureTitle(
        item: AgentTurnPresentationItem,
        userMessages: [Message],
        processMessages: [Message],
        now: Date
    ) -> String {
        let startedAt = item.record?.startedAt ?? userMessages.first?.createdAt ?? now
        let endedAt = item.record?.endedAt ?? now
        let elapsed = max(0, endedAt.timeIntervalSince(startedAt))
        let stepCount = processStepCount(processMessages)
        let summary = item.isShowingProcess
            ? "执行中"
            : "执行了\(stepCount)个步骤"
        return item.isShowingProcess
            ? "\(summary) · \(stepCount)个步骤 · \(formattedDuration(elapsed))"
            : "\(summary) · \(formattedDuration(elapsed))"
    }

    private nonisolated static func processStepCount(_ messages: [Message]) -> Int {
        let toolCallCount = messages.reduce(0) { count, message in
            count + (message.toolCalls?.count ?? 0)
        }
        return toolCallCount > 0 ? toolCallCount : messages.count
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

    private func currentStreamingStage() -> MessageStreamingStage {
        guard item.acceptsLiveActivity, let streaming = services.streaming else { return .idle }
        return streaming.stage(for: item.conversationID)
    }

    private nonisolated static func isTransientStatus(_ message: Message) -> Bool {
        message.role == .status
            && (message.turnID == nil || message.metadata["isTransientStatus"] == "true")
    }

    private nonisolated static func isPlaceholderStatus(_ message: Message) -> Bool {
        message.role == .status && message.content == "…"
    }

    private nonisolated static func deduplicated(_ messages: [Message]) -> [Message] {
        var seen: Set<UUID> = []
        return messages.filter { seen.insert($0.id).inserted }
    }
}
