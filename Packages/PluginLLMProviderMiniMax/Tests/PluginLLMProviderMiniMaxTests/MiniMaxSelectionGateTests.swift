import Foundation
import KitLLM
import ProviderLLMManager
import Testing
@testable import PluginLLMProviderMiniMax

/// 「仅当选中 MiniMax 才显示 chip」的门控行为。
@MainActor
@Suite("MiniMax 选中门控")
struct MiniMaxSelectionGateTests {

    // MARK: - 门控判定

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

    // MARK: - 观察者：初始同步

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

    // MARK: - 观察者：事件驱动

    @Test("收到 selectionChanged 切换到 MiniMax 时开启门控并拉取")
    func selectionEventEnablesGateAndFetches() {
        let manager = StubLLMManager(selectedProviderID: "openai")
        let gate = MiniMaxSelectionGate()
        var selectCount = 0
        var deselectCount = 0

        let observer = MiniMaxSelectionObserver(
            manager: manager,
            gate: gate,
            onSelect: { selectCount += 1 },
            onDeselect: { deselectCount += 1 }
        )
        observer.start()
        // start() 的初始同步：非 MiniMax → deselect 1 次。
        #expect(deselectCount == 1)

        manager.emit(.selectionChanged(
            providerID: "minimax-tokenplan",
            model: "MiniMax-M2.7",
            reason: .userSelected
        ))

        #expect(gate.isEnabled)
        #expect(selectCount == 1)
        #expect(deselectCount == 1)

        observer.cancel()
    }

    @Test("收到 selectionChanged 切走 MiniMax 时关闭门控并取消在途请求")
    func selectionEventDisablesGate() {
        let manager = StubLLMManager(selectedProviderID: "minimax-tokenplan")
        let gate = MiniMaxSelectionGate()
        var selectCount = 0
        var deselectCount = 0

        let observer = MiniMaxSelectionObserver(
            manager: manager,
            gate: gate,
            onSelect: { selectCount += 1 },
            onDeselect: { deselectCount += 1 }
        )
        observer.start()
        #expect(selectCount == 1)

        manager.emit(.selectionChanged(providerID: "openai", model: "gpt-4o", reason: .userSelected))

        #expect(!gate.isEnabled)
        #expect(selectCount == 1)
        #expect(deselectCount == 1)

        observer.cancel()
    }

    @Test("非 selectionChanged 事件不影响门控")
    func unrelatedEventsDoNotChangeGate() {
        let manager = StubLLMManager(selectedProviderID: "minimax-tokenplan")
        let gate = MiniMaxSelectionGate()
        var selectCount = 0
        var deselectCount = 0

        let observer = MiniMaxSelectionObserver(
            manager: manager,
            gate: gate,
            onSelect: { selectCount += 1 },
            onDeselect: { deselectCount += 1 }
        )
        observer.start()
        #expect(selectCount == 1)

        // 模型列表刷新与供应商注册变化都不影响「当前选的是谁」。
        manager.emit(.modelsRefreshed(providerID: "minimax-tokenplan"))
        manager.emit(.providersChanged(providerID: "openai", reason: .added))

        #expect(gate.isEnabled)
        #expect(selectCount == 1)
        #expect(deselectCount == 0)

        observer.cancel()
    }

    @Test("cancel 后不再响应事件")
    func cancelledObserverIgnoresEvents() {
        let manager = StubLLMManager(selectedProviderID: "openai")
        let gate = MiniMaxSelectionGate()
        var selectCount = 0

        let observer = MiniMaxSelectionObserver(
            manager: manager,
            gate: gate,
            onSelect: { selectCount += 1 },
            onDeselect: {}
        )
        observer.start()
        observer.cancel()

        manager.emit(.selectionChanged(
            providerID: "minimax-tokenplan",
            model: nil,
            reason: .userSelected
        ))

        #expect(selectCount == 0)
        #expect(!gate.isEnabled)
    }

    @Test("重复 start 不会重复注册观察者")
    func repeatedStartRegistersOnce() {
        let manager = StubLLMManager(selectedProviderID: "minimax-tokenplan")
        let gate = MiniMaxSelectionGate()
        var selectCount = 0

        let observer = MiniMaxSelectionObserver(
            manager: manager,
            gate: gate,
            onSelect: { selectCount += 1 },
            onDeselect: {}
        )
        observer.start()
        observer.start()

        // 关键语义：句柄只保留一条（旧的在 start 内被 cancel），
        // 因此后续事件只回调一次，不会因重复 start 而倍增。
        #expect(manager.activeObserverCount == 1)

        // 每次 start 都会重新同步一次当前选中态，故此时已回调两次。
        #expect(selectCount == 2)

        manager.emit(.selectionChanged(providerID: "openai", model: nil, reason: .userSelected))
        manager.emit(.selectionChanged(
            providerID: "minimax-tokenplan",
            model: nil,
            reason: .userSelected
        ))

        #expect(selectCount == 3)

        observer.cancel()
    }

    // MARK: - 工具栏项

    @Test("工具栏 chip 贡献 id 稳定且可撤回")
    func toolbarItemIDIsStable() {
        // onShutdown 依赖该 id 调用 removeBarItem，字面量变更会导致撤回失败。
        #expect(MiniMaxProviderPlugin.toolbarItemID == "com.coffic.lumi.plugin.llm-provider.minimax.token-plan")
    }
}

// MARK: - Stub

/// 可主动发事件的 ``LLMManaging`` 桩。
///
/// 与只返回 Noop 句柄的简化桩不同，这里真的保存回调并在 `emit(_:)` 时调用，
/// 否则观察者的「事件驱动」分支永远无法被覆盖。
@MainActor
final class StubLLMManager: LLMManaging {
    private let stubSelectedProviderID: String?
    private var callbacks: [UUID: (LLMManagerEvent) -> Void] = [:]

    init(selectedProviderID: String?) {
        self.stubSelectedProviderID = selectedProviderID
    }

    /// 当前活跃的观察者数量（用于验证重复 start）。
    var activeObserverCount: Int { callbacks.count }

    /// 向所有活跃观察者投递事件。
    func emit(_ event: LLMManagerEvent) {
        for callback in callbacks.values {
            callback(event)
        }
    }

    var selectedProviderID: String? { stubSelectedProviderID }
    var selectedModel: String? { nil }

    func addObserver(_ callback: @escaping (LLMManagerEvent) -> Void) -> any LLMManagerObserverHandle {
        let id = UUID()
        callbacks[id] = callback
        return StubObserverHandle { [weak self] in
            self?.callbacks.removeValue(forKey: id)
        }
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
}

/// 可取消的观察句柄。
@MainActor
private final class StubObserverHandle: LLMManagerObserverHandle {
    private let onCancel: () -> Void

    init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    func cancel() {
        onCancel()
    }
}
