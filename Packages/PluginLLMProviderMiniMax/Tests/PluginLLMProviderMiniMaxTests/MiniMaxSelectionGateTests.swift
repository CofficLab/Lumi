import Foundation
import KitLLM
import ProviderConversation
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

    @Test("观察者启动时补同步一次当前状态")
    func observerSyncsInitialStateOnStart() {
        let gate = MiniMaxSelectionGate()
        var selectCount = 0
        var deselectCount = 0

        let observer = MiniMaxSelectionObserver(
            capability: StubQuotaCapability(providerID: "minimax-tokenplan"),
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
            capability: StubQuotaCapability(providerID: "openai"),
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

    @Test("收到生效供应商变化切到 MiniMax 时开启门控并拉取")
    func selectionEventEnablesGateAndFetches() {
        let capability = StubQuotaCapability(providerID: "openai")
        let gate = MiniMaxSelectionGate()
        var selectCount = 0
        var deselectCount = 0

        let observer = MiniMaxSelectionObserver(
            capability: capability,
            gate: gate,
            onSelect: { selectCount += 1 },
            onDeselect: { deselectCount += 1 }
        )
        observer.start()
        // start() 的初始同步：非 MiniMax → deselect 1 次。
        #expect(deselectCount == 1)

        capability.emit(providerID: "minimax-tokenplan")

        #expect(gate.isEnabled)
        #expect(selectCount == 1)
        #expect(deselectCount == 1)

        observer.cancel()
    }

    @Test("收到生效供应商变化切走 MiniMax 时关闭门控并取消在途请求")
    func selectionEventDisablesGate() {
        let capability = StubQuotaCapability(providerID: "minimax-tokenplan")
        let gate = MiniMaxSelectionGate()
        var selectCount = 0
        var deselectCount = 0

        let observer = MiniMaxSelectionObserver(
            capability: capability,
            gate: gate,
            onSelect: { selectCount += 1 },
            onDeselect: { deselectCount += 1 }
        )
        observer.start()
        #expect(selectCount == 1)

        capability.emit(providerID: "openai")

        #expect(!gate.isEnabled)
        #expect(selectCount == 1)
        #expect(deselectCount == 1)

        observer.cancel()
    }

    @Test("cancel 后不再响应事件")
    func cancelledObserverIgnoresEvents() {
        let capability = StubQuotaCapability(providerID: "openai")
        let gate = MiniMaxSelectionGate()
        var selectCount = 0

        let observer = MiniMaxSelectionObserver(
            capability: capability,
            gate: gate,
            onSelect: { selectCount += 1 },
            onDeselect: {}
        )
        observer.start()
        observer.cancel()

        capability.emit(providerID: "minimax-tokenplan")

        #expect(selectCount == 0)
        #expect(!gate.isEnabled)
    }

    @Test("重复 start 不会重复注册观察者")
    func repeatedStartRegistersOnce() {
        let capability = StubQuotaCapability(providerID: "minimax-tokenplan")
        let gate = MiniMaxSelectionGate()
        var selectCount = 0

        let observer = MiniMaxSelectionObserver(
            capability: capability,
            gate: gate,
            onSelect: { selectCount += 1 },
            onDeselect: {}
        )
        observer.start()
        observer.start()

        // 关键语义：句柄只保留一条（旧的在 start 内被 cancel），
        // 因此后续事件只回调一次，不会因重复 start 而倍增。
        #expect(capability.activeObserverCount == 1)

        // 每次 start 都会重新同步一次当前状态，故此时已回调两次。
        #expect(selectCount == 2)

        capability.emit(providerID: "openai")
        capability.emit(providerID: "minimax-tokenplan")

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

/// 可主动发事件的 ``MiniMaxQuotaCapability`` 桩。
///
/// 与只返回 Noop 句柄的简化桩不同，这里真的保存回调并在 `emit(_:)` 时调用，
/// 否则观察者的「事件驱动」分支永远无法被覆盖。
@MainActor
final class StubQuotaCapability: MiniMaxQuotaCapability {
    private let stubProviderID: String?
    private var callbacks: [UUID: (String?) -> Void] = [:]

    init(providerID: String?) {
        self.stubProviderID = providerID
    }

    /// 当前活跃的观察者数量（用于验证重复 start）。
    var activeObserverCount: Int { callbacks.count }

    /// 向所有活跃观察者投递「生效供应商」变化。
    func emit(providerID: String?) {
        for callback in callbacks.values {
            callback(providerID)
        }
    }

    var effectiveProviderID: String? { stubProviderID }

    func addObserver(_ callback: @escaping (String?) -> Void) -> any MiniMaxQuotaObserverHandle {
        let id = UUID()
        callbacks[id] = callback
        return StubQuotaObserverHandle { [weak self] in
            self?.callbacks.removeValue(forKey: id)
        }
    }
}

/// 可取消的观察句柄。
@MainActor
private final class StubQuotaObserverHandle: MiniMaxQuotaObserverHandle {
    private let onCancel: () -> Void

    init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    func cancel() {
        onCancel()
    }
}
