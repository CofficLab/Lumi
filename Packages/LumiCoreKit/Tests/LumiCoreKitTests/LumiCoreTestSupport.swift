import Foundation
@testable import LumiCoreKit

// MARK: - 共享测试桩
//
// LumiCore 迁移到 component 架构后（一次性 init：dataRootDirectory + provider +
// chatServiceFactory），构造 LumiCore 实例用于测试时需要最小的 AgentToolProviding
// 与 LumiChatServicing 桩。本文件集中这些桩，供 LumiCoreTests 等共用，
// 避免每个测试文件各写一份。

// MARK: - EmptyAgentToolProvider

/// 不贡献任何工具/子 Agent 的 `AgentToolProviding` 桩，仅供构造 LumiCore 使用。
final class EmptyAgentToolProvider: AgentToolProviding {
    func agentTools(context: LumiPluginContext) -> [any LumiAgentTool] { [] }
    func subAgents(context: LumiPluginContext) -> [LumiSubAgentDefinition] { [] }
}

// MARK: - StubChatServicing

/// 满足协议的最小 `LumiChatServicing` 桩——所有方法返回空/默认值，字段从不触发。
/// 仅用于「满足 LumiCore 初始化签名」类的测试。
final class StubChatServicing: LumiChatServicing, @unchecked Sendable {
    var conversations: [LumiConversationSummary] = []
    var selectedConversationID: UUID?
    var providerInfos: [LumiLLMProviderInfo] = []
    var selectedProviderID: String?
    var selectedModel: String?
    var messageRenderers: [LumiMessageRendererItem] = []
    var revision: Int = 0
    var pendingMessages: [LumiPendingMessage] = []
    var routingMode: LumiModelRoutingMode = .manual
    var pendingToolConfirmation: LumiPendingToolConfirmation?

    func isSending(for conversationID: UUID?) -> Bool { false }
    @discardableResult func createConversation(title: String?) -> UUID { UUID() }
    @discardableResult
    func createConversation(title: String?, projectPath: String?, language: LumiConversationLanguage?) -> UUID { UUID() }
    func selectConversation(id: UUID) {}
    func deleteConversation(id: UUID) {}
    func updateConversationTitle(_ title: String, for conversationID: UUID) -> Bool { false }
    @discardableResult
    func setConversationProjectPath(_ projectPath: String?, for conversationID: UUID) -> Bool { false }
    func selectProvider(id: String, model: String?) {}
    func selectProvider(id: String, model: String?, for conversationID: UUID?) {}
    func providerID(for conversationID: UUID?) -> String? { nil }
    func modelName(for conversationID: UUID?) -> String? { nil }
    func provider(forID id: String) -> (any LumiLLMProvider)? { nil }
    func setRoutingMode(_ mode: LumiModelRoutingMode) {}
    func language(for conversationID: UUID?) -> LumiConversationLanguage { .english }
    func setLanguage(_ language: LumiConversationLanguage, for conversationID: UUID?) {}
    func automationLevel(for conversationID: UUID?) -> LumiAutomationLevel { .chat }
    func setAutomationLevel(_ automationLevel: LumiAutomationLevel, for conversationID: UUID?) {}
    func verbosity(for conversationID: UUID?) -> LumiResponseVerbosity { .standard }
    func setVerbosity(_ verbosity: LumiResponseVerbosity, for conversationID: UUID?) {}
    func renderer(for message: LumiChatMessage) -> LumiMessageRendererItem? { nil }
    func messages(for conversationID: UUID) -> [LumiChatMessage] { [] }
    func displayMessages(for conversationID: UUID) -> [LumiChatMessage] { [] }
    func transientStatusMessage(for conversationID: UUID) -> LumiChatMessage? { nil }
    func visibleMessages(for conversationID: UUID, limit: Int, beforeMessageID: UUID?) -> [LumiChatMessage] { [] }
    func hasEarlierMessages(for conversationID: UUID, beforeMessageID: UUID?) -> Bool { false }
    func enqueueText(_ text: String, in conversationID: UUID?) {}
    func enqueueText(_ text: String, imageAttachments: [LumiImageAttachment], in conversationID: UUID?) {}
    func continueTurn(in conversationID: UUID) {}
    func cancelSending(for conversationID: UUID?) {}
    func approvePendingTool() {}
    func rejectPendingTool() {}
    func removePendingMessage(id: UUID) {}
    func deleteMessage(id: UUID, in conversationID: UUID) {}
    func resendMessage(id: UUID, in conversationID: UUID) async {}
    func send(_ text: String, in conversationID: UUID?) async {}
    func generateEphemeralCompletion(messages: [LumiChatMessage], model: String, conversationID: UUID) async throws -> LumiChatMessage {
        throw NSError(domain: "test", code: 0)
    }
    func conversationContextUsage(for conversationID: UUID) -> LumiConversationContextUsage {
        .init(currentTokens: 0, limit: 0)
    }
}
