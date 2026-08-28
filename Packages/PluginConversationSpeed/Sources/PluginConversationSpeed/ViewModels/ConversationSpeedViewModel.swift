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

        guard let lastMessage = messages.last else {
            cachedTPS = nil
            unavailabilityReason = .waitingForResponse
            clearDetails()
            return
        }

        let latestAssistantMessage = messages.last(where: { $0.role == .assistant })
        let latestSpeedMessage = history.last?.message ?? latestAssistantMessage ?? lastMessage

        modelName = latestSpeedMessage.modelName
        outputTokens = latestSpeedMessage.outputTokenCount
        streamingDurationMs = latestSpeedMessage.speedDurationMs
        timeToFirstTokenMs = latestSpeedMessage.timeToFirstTokenMs
        providerID = latestSpeedMessage.providerID

        if let tps = history.last?.tokensPerSecond ?? lastMessage.speedTokensPerSecond {
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
        modelName = nil
        outputTokens = nil
        streamingDurationMs = nil
        timeToFirstTokenMs = nil
        providerID = nil
    }
}
