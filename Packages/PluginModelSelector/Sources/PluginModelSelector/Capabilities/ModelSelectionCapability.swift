import Foundation
import ProviderConversation
import ProviderLLMManager

/// 模型选择插件需要的最小选择能力。
///
/// 选择器本身只负责展示供应商目录；选择结果由宿主注入的 capability 决定
/// 写入当前对话还是全局 LLM 设置，避免 UI 直接绕过会话状态。
@MainActor
public protocol ModelSelectionCapability: AnyObject {
    /// 当前选中的对话；为 `nil` 时模型选择作用于全局设置。
    var selectedConversationID: UUID? { get }

    /// 当前上下文实际显示的供应商与模型。
    var selectedProviderID: String? { get }
    var selectedModel: String? { get }

    /// 在当前上下文中选择供应商与模型。
    func select(providerID: String, model: String?)

    /// 订阅会话选择或会话模型变化，用于刷新选择器显示。
    func addConversationObserver(_ callback: @escaping (ConversationEvent) -> Void) -> any ConversationObserverHandle
}

/// 将内核的会话与 LLM 管理能力收窄为模型选择插件所需的 capability。
@MainActor
final class ModelSelectionCapabilityAdapter: ModelSelectionCapability {
    private let conversations: (any ConversationManaging)?
    private let llmManager: any LLMManaging

    init(
        conversations: (any ConversationManaging)?,
        llmManager: any LLMManaging
    ) {
        self.conversations = conversations
        self.llmManager = llmManager
    }

    var selectedConversationID: UUID? {
        conversations?.selectedConversationID
    }

    var selectedProviderID: String? {
        guard let conversationID = selectedConversationID else {
            return llmManager.selectedProviderID
        }
        return conversations?.providerID(for: conversationID) ?? llmManager.selectedProviderID
    }

    var selectedModel: String? {
        guard let conversationID = selectedConversationID else {
            return llmManager.selectedModel
        }
        return conversations?.modelName(for: conversationID) ?? llmManager.selectedModel
    }

    func select(providerID: String, model: String?) {
        if let conversationID = selectedConversationID, let conversations {
            conversations.selectProvider(
                id: providerID,
                model: model,
                for: conversationID
            )
        } else {
            llmManager.select(providerID: providerID, model: model)
        }
    }

    func addConversationObserver(_ callback: @escaping (ConversationEvent) -> Void) -> any ConversationObserverHandle {
        conversations?.addConversationObserver(callback) ?? NoopConversationObserverHandle()
    }
}
