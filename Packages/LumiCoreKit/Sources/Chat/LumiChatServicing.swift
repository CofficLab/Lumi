import Foundation

@MainActor
public protocol LumiChatServicing: AnyObject {
    var conversations: [LumiConversationSummary] { get }
    var selectedConversationID: UUID? { get }
    var providerInfos: [LumiLLMProviderInfo] { get }
    var selectedProviderID: String? { get }
    var selectedModel: String? { get }
    var messageRenderers: [LumiMessageRendererItem] { get }
    var revision: Int { get }
    var agentTools: [any LumiAgentTool] { get }

    @discardableResult
    func createConversation(title: String?) -> UUID

    func selectConversation(id: UUID)
    func deleteConversation(id: UUID)
    func selectProvider(id: String, model: String?)
    func language(for conversationID: UUID?) -> LumiConversationLanguage
    func setLanguage(_ language: LumiConversationLanguage, for conversationID: UUID?)
    func automationLevel(for conversationID: UUID?) -> LumiAutomationLevel
    func setAutomationLevel(_ automationLevel: LumiAutomationLevel, for conversationID: UUID?)
    func verbosity(for conversationID: UUID?) -> LumiResponseVerbosity
    func setVerbosity(_ verbosity: LumiResponseVerbosity, for conversationID: UUID?)
    func registerToolService(_ toolService: (any LumiToolServicing)?)
    func renderer(for message: LumiChatMessage) -> LumiMessageRendererItem?
    func messages(for conversationID: UUID) -> [LumiChatMessage]
    func send(_ text: String, in conversationID: UUID?) async
}
