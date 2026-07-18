import Foundation
import LumiComponentLLMProvider
import LumiComponentMessage

@MainActor
public protocol LumiChatServicing: AnyObject, ObservableObject {
    var conversations: [LumiConversationSummary] { get }
    var selectedConversationID: UUID? { get }
    var providerInfos: [LumiLLMProviderInfo] { get }
    var selectedProviderID: String? { get }
    var selectedModel: String? { get }
    var messageRenderers: [LumiMessageRendererItem] { get }
    var revision: Int { get }
    var pendingMessages: [LumiPendingMessage] { get }
    var routingMode: LumiModelRoutingMode { get }
    var pendingToolConfirmation: LumiPendingToolConfirmation? { get }

    func isSending(for conversationID: UUID?) -> Bool

    @discardableResult
    func createConversation(title: String?) -> UUID
    @discardableResult
    func createConversation(
        title: String?,
        projectPath: String?,
        language: LumiConversationLanguage?
    ) -> UUID

    func selectConversation(id: UUID)
    func deleteConversation(id: UUID)
    func updateConversationTitle(_ title: String, for conversationID: UUID) -> Bool
    @discardableResult
    func setConversationProjectPath(_ projectPath: String?, for conversationID: UUID) -> Bool
    func selectProvider(id: String, model: String?)
    func selectProvider(id: String, model: String?, for conversationID: UUID?)
    func providerID(for conversationID: UUID?) -> String?
    /// 根据 provider id 获取运行时实例（用于子 Agent 动态解析）。
    func provider(forID id: String) -> (any LumiLLMProvider)?
    func modelName(for conversationID: UUID?) -> String?
    func setRoutingMode(_ mode: LumiModelRoutingMode)
    func language(for conversationID: UUID?) -> LumiConversationLanguage
    func setLanguage(_ language: LumiConversationLanguage, for conversationID: UUID?)
    func automationLevel(for conversationID: UUID?) -> LumiAutomationLevel
    func setAutomationLevel(_ automationLevel: LumiAutomationLevel, for conversationID: UUID?)
    func verbosity(for conversationID: UUID?) -> LumiResponseVerbosity
    func setVerbosity(_ verbosity: LumiResponseVerbosity, for conversationID: UUID?)
    func renderer(for message: LumiChatMessage) -> LumiMessageRendererItem?
    func messages(for conversationID: UUID) -> [LumiChatMessage]
    func displayMessages(for conversationID: UUID) -> [LumiChatMessage]
    func transientStatusMessage(for conversationID: UUID) -> LumiChatMessage?
    func visibleMessages(for conversationID: UUID, limit: Int, beforeMessageID: UUID?) -> [LumiChatMessage]
    func hasEarlierMessages(for conversationID: UUID, beforeMessageID: UUID?) -> Bool
    func enqueueText(_ text: String, in conversationID: UUID?)
    func enqueueText(_ text: String, imageAttachments: [LumiImageAttachment], in conversationID: UUID?)
    /// 在不写入任何用户消息的前提下，为该会话重启一轮 agent turn（用于无感自动续聊）。
    func continueTurn(in conversationID: UUID)
    func cancelSending(for conversationID: UUID?)
    func approvePendingTool()
    func rejectPendingTool()
    func removePendingMessage(id: UUID)
    func deleteMessage(id: UUID, in conversationID: UUID)
    func resendMessage(id: UUID, in conversationID: UUID) async
    func send(_ text: String, in conversationID: UUID?) async
    func generateEphemeralCompletion(
        messages: [LumiChatMessage],
        model: String,
        conversationID: UUID
    ) async throws -> LumiChatMessage
    func conversationContextUsage(for conversationID: UUID) -> LumiConversationContextUsage
}
