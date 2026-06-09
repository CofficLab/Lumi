import Foundation

@MainActor
public protocol LumiChatServicing: AnyObject, ObservableObject {
    var conversations: [LumiConversationSummary] { get }
    var selectedConversationID: UUID? { get }
    var providerInfos: [LumiLLMProviderInfo] { get }
    var selectedProviderID: String? { get }
    var selectedModel: String? { get }
    var messageRenderers: [LumiMessageRendererItem] { get }
    var revision: Int { get }
    var agentTools: [any LumiAgentTool] { get }
    var pendingMessages: [LumiPendingMessage] { get }
    var routingMode: LumiModelRoutingMode { get }
    var pendingToolConfirmation: LumiPendingToolConfirmation? { get }

    func isSending(for conversationID: UUID?) -> Bool

    @discardableResult
    func createConversation(title: String?) -> UUID

    func selectConversation(id: UUID)
    func deleteConversation(id: UUID)
    func updateConversationTitle(_ title: String, for conversationID: UUID) -> Bool
    func selectProvider(id: String, model: String?)
    func selectProvider(id: String, model: String?, for conversationID: UUID?)
    func providerID(for conversationID: UUID?) -> String?
    func modelName(for conversationID: UUID?) -> String?
    func setRoutingMode(_ mode: LumiModelRoutingMode)
    func language(for conversationID: UUID?) -> LumiConversationLanguage
    func setLanguage(_ language: LumiConversationLanguage, for conversationID: UUID?)
    func automationLevel(for conversationID: UUID?) -> LumiAutomationLevel
    func setAutomationLevel(_ automationLevel: LumiAutomationLevel, for conversationID: UUID?)
    func verbosity(for conversationID: UUID?) -> LumiResponseVerbosity
    func setVerbosity(_ verbosity: LumiResponseVerbosity, for conversationID: UUID?)
    func registerToolService(_ toolService: (any LumiToolServicing)?)
    func renderer(for message: LumiChatMessage) -> LumiMessageRendererItem?
    func messages(for conversationID: UUID) -> [LumiChatMessage]
    func displayMessages(for conversationID: UUID) -> [LumiChatMessage]
    func transientStatusMessage(for conversationID: UUID) -> LumiChatMessage?
    func visibleMessages(for conversationID: UUID, limit: Int, beforeMessageID: UUID?) -> [LumiChatMessage]
    func hasEarlierMessages(for conversationID: UUID, beforeMessageID: UUID?) -> Bool
    func enqueueText(_ text: String, in conversationID: UUID?)
    func enqueueText(_ text: String, imageAttachments: [LumiImageAttachment], in conversationID: UUID?)
    func cancelSending(for conversationID: UUID?)
    func approvePendingTool()
    func rejectPendingTool()
    func removePendingMessage(id: UUID)
    func deleteMessage(id: UUID, in conversationID: UUID)
    func resendMessage(id: UUID, in conversationID: UUID) async
    func send(_ text: String, in conversationID: UUID?) async
}
