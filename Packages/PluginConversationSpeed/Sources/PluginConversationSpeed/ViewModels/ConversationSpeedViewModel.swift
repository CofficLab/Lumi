import Combine
import Foundation
import ProviderMessage

/// 工具栏速度展示状态。
///
/// ViewModel 只保存可展示状态和计算结果，不持有任何 Provider observer token。
/// Provider 的订阅及生命周期由插件下的 Observer 对象负责。
@MainActor
final class ConversationSpeedViewModel: ObservableObject {
    @Published private(set) var selectedConversationID: UUID?
    @Published private(set) var cachedTPS: Double?
    @Published private(set) var unavailabilityReason: SpeedUnavailability = .waitingForResponse
    @Published private(set) var speedHistory: [SpeedSample] = []

    @Published private(set) var modelName: String?
    @Published private(set) var outputTokens: Int?
    @Published private(set) var streamingDurationMs: Double?
    @Published private(set) var timeToFirstTokenMs: Double?
    @Published private(set) var providerID: String?

    /// 会话内的 LLM 请求次数（assistant 消息数）。
    @Published private(set) var requestCount: Int = 0

    /// 刷新代次（#1156）：每次选择变化 / 消息插入事件发生时同步递增。
    /// 异步快照在排程时记录代次，写回前再次比对；期间出现过更新的事件
    /// 就说明快照已过时，必须丢弃，否则旧选择快照会覆盖新插入的统计。
    private(set) var refreshGeneration: UInt64 = 0

    /// 记录一次新的刷新事件，返回供异步任务比对的代次。
    @discardableResult
    func beginRefresh() -> UInt64 {
        refreshGeneration &+= 1
        return refreshGeneration
    }

    func selectConversation(_ conversationID: UUID?, messages: [Message]) {
        if selectedConversationID != conversationID {
            resetDisplayState()
        }
        selectedConversationID = conversationID
        updateState(conversationID: conversationID, messages: messages)
    }

    func refresh(conversationID: UUID, messages: [Message]) {
        guard selectedConversationID == conversationID else { return }
        updateState(conversationID: conversationID, messages: messages)
    }

    private func updateState(conversationID: UUID?, messages: [Message]) {
        guard conversationID != nil else {
            cachedTPS = nil
            unavailabilityReason = .noConversationSelected
            speedHistory = []
            clearDetails()
            return
        }

        let history = SpeedSample.samples(from: messages)
        speedHistory = history
        requestCount = messages.filter { $0.role == .assistant }.count

        guard !messages.isEmpty else {
            cachedTPS = nil
            unavailabilityReason = .waitingForResponse
            clearDetails()
            return
        }

        let latestAssistantMessage = messages.last(where: { $0.role == .assistant })

        guard let latestAssistantMessage else {
            cachedTPS = nil
            unavailabilityReason = .waitingForResponse
            clearDetails()
            return
        }

        // Current speed 及其详情必须描述最新一条 assistant 响应。
        // 不能回退到历史中最后一条带指标的响应，否则旧响应的 TPS/路由会冒充当前响应。
        modelName = latestAssistantMessage.modelName
        outputTokens = latestAssistantMessage.outputTokenCount
        streamingDurationMs = latestAssistantMessage.speedDurationMs
        timeToFirstTokenMs = latestAssistantMessage.speedTimeToFirstTokenMs
        providerID = latestAssistantMessage.providerID

        if let tps = latestAssistantMessage.speedTokensPerSecond {
            cachedTPS = tps
            unavailabilityReason = .waitingForResponse
            return
        }

        cachedTPS = nil
        unavailabilityReason = SpeedUnavailability.reason(for: latestAssistantMessage)
    }

    private func resetDisplayState() {
        cachedTPS = nil
        unavailabilityReason = .waitingForResponse
        speedHistory = []
        clearDetails()
    }

    private func clearDetails() {
        requestCount = 0
        modelName = nil
        outputTokens = nil
        streamingDurationMs = nil
        timeToFirstTokenMs = nil
        providerID = nil
    }
}
