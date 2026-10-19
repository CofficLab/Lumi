import Foundation
import Testing
import KitLLM
import ProviderLLMManager
@testable import PluginLLMProviderMiniMax

/// 「仅当选中 MiniMax 才显示 chip」的门控行为。
@MainActor
@Suite("MiniMax 选中门控")
struct MiniMaxSelectionGateTests {

    @Test("三个 MiniMax 协议变体都算选中")
    func allVariantIDsEnableGate() {
        for id in MiniMaxSelectionGate.providerIDs {
            let gate = MiniMaxSelectionGate()
            gate.update(providerID: id)
            #expect(gate.isEnabled, "provider \(id) 应展示配额 chip")
        }
    }

    @Test("其它供应商不展示 chip")
    func otherProvidersDisableGate() {
        let gate = MiniMaxSelectionGate()

        for id in ["openai", "anthropic", "minimax-lookalike", "tokenhub"] {
            gate.update(providerID: id)
            #expect(!gate.isEnabled, "provider \(id) 不应展示配额 chip")
        }
    }

    @Test("未选中任何供应商时不展示 chip")
    func nilProviderDisablesGate() {
        let gate = MiniMaxSelectionGate(isEnabled: true)

        gate.update(providerID: nil)

        #expect(!gate.isEnabled)
    }

    @Test("反复切换供应商时门控跟随最新状态")
    func gateTracksLatestSelection() {
        let gate = MiniMaxSelectionGate()

        gate.update(providerID: "openai")
        #expect(!gate.isEnabled)

        gate.update(providerID: "minimax-tokenplan")
        #expect(gate.isEnabled)

        gate.update(providerID: "anthropic")
        #expect(!gate.isEnabled)
    }

    @Test("观察者启动时补同步一次当前选中态")
    func observerSyncsInitialStateOnStart() {
        let gate = MiniMaxSelectionGate()
        var selectCount = 0
        var deselectCount = 0

        let observer = MiniMaxSelectionObserver(
            manager: StubLLMManager(selectedProviderID: "minimax-tokenplan"),
            gate: gate,
            onSelect: { selectCount += 1 },
            onDeselect: { deselectCount += 1 }
        )
        observer.start()

        #expect(gate.isEnabled)
        #expect(selectCount == 1)
        #expect(deselectCount == 0)

        observer.cancel()
    }

    @Test("初始未选中 MiniMax 时触发取消回调")
    func observerTriggersDeselectWhenOtherProviderSelected() {
        let gate = MiniMaxSelectionGate()
        var selectCount = 0
        var deselectCount = 0

        let observer = MiniMaxSelectionObserver(
            manager: StubLLMManager(selectedProviderID: "openai"),
            gate: gate,
            onSelect: { selectCount += 1 },
            onDeselect: { deselectCount += 1 }
        )
        observer.start()

        #expect(!gate.isEnabled)
        #expect(selectCount == 0)
        #expect(deselectCount == 1)

        observer.cancel()
    }

    @Test("工具栏 chip 贡献 id 稳定且可撤回")
    func toolbarItemIDIsStable() {
        // onShutdown 依赖该 id 调用 removeBarItem，字面量变更会导致撤回失败。
        #expect(MiniMaxProviderPlugin.toolbarItemID == "com.coffic.lumi.plugin.llm-provider.minimax.token-plan")
    }
}

// MARK: - Stub

/// 只实现测试所需成员的 ``LLMManaging`` 桩。
@MainActor
private final class StubLLMManager: LLMManaging {
    private let stubSelectedProviderID: String?

    init(selectedProviderID: String?) {
        self.stubSelectedProviderID = selectedProviderID
    }

    var selectedProviderID: String? { stubSelectedProviderID }
    var selectedModel: String? { nil }

    func addObserver(_ callback: @escaping (LLMManagerEvent) -> Void) -> any LLMManagerObserverHandle {
        NoopHandle()
    }

    func allProviders() -> [any SuperLLMProvider] { [] }
    func provider(id: String) -> (any SuperLLMProvider)? { nil }
    func provider(for modelID: LLMModelID) -> (any SuperLLMProvider)? { nil }
    var providerCount: Int { 0 }
    func register(_ provider: any SuperLLMProvider) throws {}
    func unregister(id: String) {}
    func models(for providerID: String) -> [String] { [] }
    func select(providerID: String, model: String?, reason: ModelSelectionReason) {}
    func modelID(providerID: String, model: String?) -> LLMModelID? { nil }
    func notifyModelsRefreshed(providerID: String) {}

    // MARK: SuperLLMProvider

    var providerID: String { "stub" }
    var providerInfo: LLMProviderInfo {
        LLMProviderInfo(
            id: "stub",
            displayName: "Stub",
            description: "test stub",
            defaultModel: "stub",
            models: [],
            websiteURL: URL(string: "https://example.com")!,
            apiFormat: .openAI,
            apiKeyStorageKey: "stub"
        )
    }
    func complete(_ request: LLMRequest) async throws -> LLMResponse {
        throw VendorAPIError.requestFailed("stub")
    }

    private final class NoopHandle: LLMManagerObserverHandle {
        func cancel() {}
    }
}
