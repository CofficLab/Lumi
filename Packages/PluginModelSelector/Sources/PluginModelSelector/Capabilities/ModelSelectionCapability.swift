import Foundation
import KitLLM
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
    var selectedModelID: String? { get }

    /// 在当前上下文中选择供应商与模型。
    func select(providerID: String, model: String?)
    func select(modelID: String)

    /// 订阅会话选择或会话模型变化，用于刷新选择器显示。
    func addConversationObserver(_ callback: @escaping (ConversationEvent) -> Void) -> any ConversationObserverHandle
}

public extension ModelSelectionCapability {
    var selectedModelID: String? {
        guard let selectedProviderID, let selectedModel else { return nil }
        return LLMModelID(providerID: selectedProviderID, modelID: selectedModel)?.rawValue
    }

    func select(modelID rawValue: String) {
        guard let modelID = LLMModelID(rawValue: rawValue) else { return }
        select(providerID: modelID.providerID, model: modelID.modelID)
    }
}

/// 将内核的会话与 LLM 管理能力收窄为模型选择插件所需的 capability。
@MainActor
final class ModelSelectionCapabilityAdapter: ModelSelectionCapability {
    private let conversations: (any ConversationManaging)?
    private let llmManager: any LLMManaging
    /// 模型切换时间线记录器；为 nil 时不写时间线（消息管理器不可用）。
    private let timelineRecorder: ModelSwitchTimelineRecorder?

    init(
        conversations: (any ConversationManaging)?,
        llmManager: any LLMManaging,
        timelineRecorder: ModelSwitchTimelineRecorder? = nil
    ) {
        self.conversations = conversations
        self.llmManager = llmManager
        self.timelineRecorder = timelineRecorder
    }

    var selectedConversationID: UUID? {
        conversations?.selectedConversationID
    }

    var selectedProviderID: String? {
        guard let modelID = selectedModelID.flatMap(LLMModelID.init(rawValue:)) else { return nil }
        return modelID.providerID
    }

    var selectedModel: String? {
        selectedModelID.flatMap(LLMModelID.init(rawValue:))?.modelID
    }

    var selectedModelID: String? {
        guard let conversationID = selectedConversationID else {
            return llmManager.selectedModelID?.rawValue
        }
        if let conversationModelID = conversations?.modelID(for: conversationID),
           let parsed = LLMModelID(rawValue: conversationModelID),
           llmManager.modelRoute(for: parsed) != nil {
            return parsed.rawValue
        }
        return llmManager.selectedModelID?.rawValue
    }

    func select(providerID: String, model: String?) {
        guard let modelID = llmManager.modelID(providerID: providerID, model: model) else { return }
        select(modelID: modelID.rawValue)
    }

    func select(modelID rawValue: String) {
        guard let modelID = LLMModelID(rawValue: rawValue),
              llmManager.modelRoute(for: modelID) != nil else { return }
        // 切换**前**的模型快照：必须在写入之前取，否则拿到的已是新模型。
        let previousModelID = selectedModelID.flatMap(LLMModelID.init(rawValue:))
        let conversationID = selectedConversationID

        if let conversationID, let conversations {
            conversations.selectModel(id: modelID.rawValue, for: conversationID)
        } else {
            llmManager.select(modelID: modelID, reason: .userSelected)
        }

        recordSwitch(
            conversationID: conversationID,
            previous: previousModelID,
            current: modelID
        )
    }

    /// 把本次模型切换写进会话时间线。
    ///
    /// 只有「有选中会话」才记录：没有会话时模型只改了全局默认，
    /// 不存在「这个会话换了模型」这件事可写。
    private func recordSwitch(
        conversationID: UUID?,
        previous: LLMModelID?,
        current: LLMModelID
    ) {
        guard let timelineRecorder, let conversationID else { return }
        // 确认切换**确实生效**再记录。
        //
        // 写入会话可能静默失败（会话已被整表重载替换、不在缓存数组里时
        // `selectModel` 的 guard 会直接返回），此时模型其实没换，写一条
        // 「已切换」的时间线消息就是误导。
        guard let effective = selectedModelID.flatMap(LLMModelID.init(rawValue:)),
              effective == current else { return }
        timelineRecorder.record(
            conversationID: conversationID,
            transition: ModelSwitchTimelineRecorder.Transition(
                fromProviderID: previous?.providerID,
                fromModelName: previous?.modelID,
                toProviderID: current.providerID,
                toModelName: current.modelID
            )
        )
    }

    func addConversationObserver(_ callback: @escaping (ConversationEvent) -> Void) -> any ConversationObserverHandle {
        conversations?.addConversationObserver(callback) ?? NoopConversationObserverHandle()
    }
}
