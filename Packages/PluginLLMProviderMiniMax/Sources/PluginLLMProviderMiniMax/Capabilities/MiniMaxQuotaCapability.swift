import Foundation
import KitLLM
import ProviderConversation
import ProviderLLMManager

/// MiniMax 配额 chip 所需的最小能力：解析「当前对话实际生效的供应商」。
///
/// ## 为什么不能只看全局选中项
///
/// 模型可以钉在**单个对话**上（`ConversationManaging.modelID(for:)`），
/// 全局选中项（`LLMManaging.selectedModelID`）与对话钉选可能指向不同供应商。
/// 请求实际发给谁由「对话钉选优先、否则回落到全局选中」决定
/// （与 `AgentLoopManager.resolveModelRoute(for:)` 同一口径），
/// 配额 chip 必须用同一套口径，否则会出现两种错误展示：
///
/// - 切到用 MiniMax 的对话，工具栏却不显示 MiniMax 剩余额度；
/// - 切到用其它供应商的对话，反而显示 MiniMax 剩余额度。
///
/// ## 能力边界
///
/// 本协议只暴露「生效供应商 id」与「它的变化」，不泄漏
/// `LLMManagerObserverHandle` / `ConversationObserverHandle` 等 Provider 句柄类型。
@MainActor
protocol MiniMaxQuotaCapability: AnyObject {
    /// 当前对话实际生效的供应商 id；无法判定时为 `nil`。
    var effectiveProviderID: String? { get }

    /// 订阅「生效供应商」变化；仅在值真正变化时回调。
    ///
    /// - Returns: 注销句柄；调用 `cancel()` 后停止接收。
    func addObserver(_ callback: @escaping (String?) -> Void) -> any MiniMaxQuotaObserverHandle
}

/// 能力侧自有的观察句柄协议（不暴露 Provider 的句柄类型）。
@MainActor
protocol MiniMaxQuotaObserverHandle: AnyObject {
    func cancel()
}

/// 将 `LLMManaging` 与 `ConversationManaging` 收窄成配额 chip 需要的
/// 「生效供应商」能力。
///
/// ## 生效口径
///
/// 1. 当前**选中对话**钉选了模型，且该模型仍能解析出路由 → 用对话的供应商；
/// 2. 否则回落到**全局选中**模型的路由；
/// 3. 再否则用全局选中的供应商 id（可能尚未注册到路由表）。
///
/// ## 生命周期
///
/// 订阅句柄由本类型持有，插件在 `onShutdown` 显式调用 ``cancel()`` 释放。
@MainActor
final class MiniMaxQuotaCapabilityAdapter: MiniMaxQuotaCapability {
    private let llmManager: any LLMManaging
    private let conversations: (any ConversationManaging)?

    private var managerHandle: (any LLMManagerObserverHandle)?
    private var conversationHandle: (any ConversationObserverHandle)?
    private var selectionHandle: (any SelectedConversationObserverHandle)?
    private var observers: [UUID: (String?) -> Void] = [:]

    /// 上一次解析出的生效供应商；用于抑制重复通知。
    private var cachedProviderID: String?

    init(llmManager: any LLMManaging, conversations: (any ConversationManaging)?) {
        self.llmManager = llmManager
        self.conversations = conversations
        cachedProviderID = Self.resolveEffectiveProviderID(
            llmManager: llmManager,
            conversations: conversations
        )
        startObserving()
    }

    var effectiveProviderID: String? { cachedProviderID }

    @discardableResult
    func addObserver(_ callback: @escaping (String?) -> Void) -> any MiniMaxQuotaObserverHandle {
        let id = UUID()
        observers[id] = callback
        return Handle { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }

    /// 释放全部订阅（插件关闭时调用）。
    func cancel() {
        managerHandle?.cancel()
        managerHandle = nil
        conversationHandle?.cancel()
        conversationHandle = nil
        selectionHandle?.cancel()
        selectionHandle = nil
        observers.removeAll()
    }

    // MARK: - Observation

    private func startObserving() {
        managerHandle = llmManager.addObserver { [weak self] event in
            switch event {
            case .selectionChanged, .modelsRefreshed, .providersChanged:
                // 全局选中变化、模型池刷新、供应商注册变化都会改变
                // 「对话钉选能否解析出路由」，因此需要重新判定。
                self?.refresh()
            }
        }

        guard let conversations else { return }

        conversationHandle = conversations.addConversationObserver { [weak self] event in
            switch event {
            case .selected, .providerChanged, .created, .deleted, .updated, .listChanged:
                self?.refresh()
            default:
                break
            }
        }

        selectionHandle = conversations.addSelectedConversationObserver { [weak self] _ in
            self?.refresh()
        }
    }

    /// 重新解析生效供应商；仅在结果变化时通知观察者。
    private func refresh() {
        let newValue = Self.resolveEffectiveProviderID(
            llmManager: llmManager,
            conversations: conversations
        )
        guard newValue != cachedProviderID else { return }
        cachedProviderID = newValue
        for callback in observers.values {
            callback(newValue)
        }
    }

    // MARK: - Resolution

    /// 「对话钉选优先、否则回落到全局选中」——与 AgentLoop 路由口径一致。
    static func resolveEffectiveProviderID(
        llmManager: any LLMManaging,
        conversations: (any ConversationManaging)?
    ) -> String? {
        if let conversationID = conversations?.selectedConversationID,
           let conversationModelID = conversations?.modelID(for: conversationID),
           let parsed = LLMModelID(rawValue: conversationModelID),
           let route = llmManager.modelRoute(for: parsed) {
            return route.providerID
        }
        if let globalModelID = llmManager.selectedModelID,
           let route = llmManager.modelRoute(for: globalModelID) {
            return route.providerID
        }
        return llmManager.selectedProviderID
    }
}

/// 能力侧的观察句柄实现。
@MainActor
private final class Handle: MiniMaxQuotaObserverHandle {
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
