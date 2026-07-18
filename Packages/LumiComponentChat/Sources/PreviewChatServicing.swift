import Foundation
import LumiComponentLLMProvider
import LumiComponentMessage

/// 一个全占位的 `LumiChatServicing` 实现，供 SwiftUI Preview / 测试 stub 使用。
///
/// `LumiCore.chatService` 在重构后是非可选的，因此 `LumiCoreAccessing` 的 mock
/// （如各 plugin 的 `PreviewLumiCoreStub`）必须返回一个非空 chatService。
/// 本类用最小空实现满足协议要求——方法被调用时返回安全默认值（空集合 / false / nil），
/// Preview 不会真正驱动对话流程。
@MainActor
public final class PreviewChatServicing: ObservableObject, LumiChatServicing, @unchecked Sendable {
    public init() {}

    // MARK: - Required computed properties

    public var conversations: [LumiConversationSummary] = []
    public var selectedConversationID: UUID?
    public var providerInfos: [LumiLLMProviderInfo] = []
    public var selectedProviderID: String?
    public var selectedModel: String?
    public var messageRenderers: [LumiMessageRendererItem] = []
    public var revision: Int = 0
    public var pendingMessages: [LumiPendingMessage] = []
    public var routingMode: LumiModelRoutingMode = .manual
    public var pendingToolConfirmation: LumiPendingToolConfirmation?

    // MARK: - Required methods（占位实现，Preview 不会真正调用）

    public func isSending(for conversationID: UUID?) -> Bool { false }

    @discardableResult public func createConversation(title: String?) -> UUID { UUID() }
    @discardableResult
    public func createConversation(title: String?, projectPath: String?, language: LumiConversationLanguage?) -> UUID { UUID() }
    public func selectConversation(id: UUID) {}
    public func deleteConversation(id: UUID) {}
    public func updateConversationTitle(_ title: String, for conversationID: UUID) -> Bool { false }
    @discardableResult
    public func setConversationProjectPath(_ projectPath: String?, for conversationID: UUID) -> Bool { false }
    public func selectProvider(id: String, model: String?) {}
    public func selectProvider(id: String, model: String?, for conversationID: UUID?) {}
    public func providerID(for conversationID: UUID?) -> String? { nil }
    public func provider(forID id: String) -> (any LumiLLMProvider)? { nil }
    public func modelName(for conversationID: UUID?) -> String? { nil }
    public func setRoutingMode(_ mode: LumiModelRoutingMode) {}
    public func language(for conversationID: UUID?) -> LumiConversationLanguage { .english }
    public func setLanguage(_ language: LumiConversationLanguage, for conversationID: UUID?) {}
    public func automationLevel(for conversationID: UUID?) -> LumiAutomationLevel { .chat }
    public func setAutomationLevel(_ automationLevel: LumiAutomationLevel, for conversationID: UUID?) {}
    public func verbosity(for conversationID: UUID?) -> LumiResponseVerbosity { .standard }
    public func setVerbosity(_ verbosity: LumiResponseVerbosity, for conversationID: UUID?) {}
    public func renderer(for message: LumiChatMessage) -> LumiMessageRendererItem? { nil }
    public func messages(for conversationID: UUID) -> [LumiChatMessage] { [] }
    public func displayMessages(for conversationID: UUID) -> [LumiChatMessage] { [] }
    public func transientStatusMessage(for conversationID: UUID) -> LumiChatMessage? { nil }
    public func visibleMessages(for conversationID: UUID, limit: Int, beforeMessageID: UUID?) -> [LumiChatMessage] { [] }
    public func hasEarlierMessages(for conversationID: UUID, beforeMessageID: UUID?) -> Bool { false }
    public func enqueueText(_ text: String, in conversationID: UUID?) {}
    public func enqueueText(_ text: String, imageAttachments: [LumiImageAttachment], in conversationID: UUID?) {}
    public func continueTurn(in conversationID: UUID) {}
    public func cancelSending(for conversationID: UUID?) {}
    public func approvePendingTool() {}
    public func rejectPendingTool() {}
    public func removePendingMessage(id: UUID) {}
    public func deleteMessage(id: UUID, in conversationID: UUID) {}
    public func resendMessage(id: UUID, in conversationID: UUID) async {}
    public func send(_ text: String, in conversationID: UUID?) async {}
    public func generateEphemeralCompletion(messages: [LumiChatMessage], model: String, conversationID: UUID) async throws -> LumiChatMessage {
        throw NSError(domain: "PreviewChatServicing", code: 0)
    }
    public func conversationContextUsage(for conversationID: UUID) -> LumiConversationContextUsage {
        .init(currentTokens: 0, limit: 0)
    }
}
