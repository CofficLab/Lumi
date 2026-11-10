import Foundation
import KitLLM
import LumiUI
import ProviderConversation
import ProviderLLMManager
import ProviderToast
import Testing
@testable import PluginModelSelector

/// 选择结果反馈只在真正生效时出现（回归 #880）。
@Suite("Model selection feedback")
@MainActor
struct ModelSelectionFeedbackTests {
    @Test("Selection dropped by the capability records no usage and shows no toast")
    func droppedSelectionProducesNoSuccessFeedback() throws {
        let manager = DefaultLLMManager()
        try manager.register(FeedbackTestProvider(id: "feedback-provider", models: ["feedback-model"]))
        let selection = SpySelection(appliesSelection: false)
        let toast = SpyToast()
        let usageStore = ProviderUsageStore(directory: nil)
        let viewModel = ModelSelectorViewModel(
            box: LLMProviderManagerBox(manager: manager, selection: selection),
            usageStore: usageStore,
            toastCapability: toast
        )

        viewModel.select(providerID: "feedback-provider", model: "feedback-model")

        #expect(selection.selectCalls == 1)
        #expect(usageStore.usageCount(for: "feedback-provider") == 0)
        #expect(toast.notifications.isEmpty)
    }

    @Test("Applied selection records usage and shows the success toast")
    func appliedSelectionProducesSuccessFeedback() throws {
        let manager = DefaultLLMManager()
        try manager.register(FeedbackTestProvider(id: "feedback-provider", models: ["feedback-model"]))
        let selection = SpySelection(appliesSelection: true)
        let toast = SpyToast()
        let usageStore = ProviderUsageStore(directory: nil)
        let viewModel = ModelSelectorViewModel(
            box: LLMProviderManagerBox(manager: manager, selection: selection),
            usageStore: usageStore,
            toastCapability: toast
        )

        viewModel.select(providerID: "feedback-provider", model: "feedback-model")

        #expect(usageStore.usageCount(for: "feedback-provider") == 1)
        #expect(toast.notifications.count == 1)
    }
}

@MainActor
private final class SpySelection: ModelSelectionCapability {
    var selectedConversationID: UUID?
    var selectedProviderID: String?
    var selectedModel: String?
    private let appliesSelection: Bool
    private(set) var selectCalls = 0
    private var observers: [(ConversationEvent) -> Void] = []

    init(appliesSelection: Bool) {
        self.appliesSelection = appliesSelection
    }

    func select(providerID: String, model: String?) {
        selectCalls += 1
        guard appliesSelection else { return }
        selectedProviderID = providerID
        selectedModel = model
        // 真实 adapter 写入会话后会同步广播 .providerChanged，box 据此刷新快照。
        observers.forEach { $0(.providerChanged(UUID())) }
    }

    func addConversationObserver(
        _ callback: @escaping (ConversationEvent) -> Void
    ) -> any ConversationObserverHandle {
        observers.append(callback)
        return SpyConversationObserverHandle()
    }
}

@MainActor
private final class SpyConversationObserverHandle: ConversationObserverHandle {
    func cancel() {}
}

@MainActor
private final class SpyToast: ModelSelectorToastCapability {
    private(set) var notifications: [(title: String, detail: String?)] = []

    func notify(_ title: String, detail: String?, style: LumiToastStyle) {
        notifications.append((title, detail))
    }
}

@MainActor
private final class FeedbackTestProvider: ManagedLLMProvider {
    let providerInfo: LLMProviderInfo

    init(id: String, models: [String]) {
        providerInfo = LLMProviderInfo(
            id: id,
            displayName: id,
            defaultModel: models[0],
            models: models.map { LLMModelInfo(id: $0) }
        )
    }

    var providerID: String { providerInfo.id }

    func complete(_ request: LLMRequest) async throws -> LLMResponse {
        LLMResponse(content: "ok", model: request.model)
    }
}
