import Testing
import KernelLumi
@testable import LLMProviderStepFunPlugin

/// `StepFunSubAgentsGate` 的状态机契约测试。
///
/// gate 把「供应商是否可用」与异步可用性探测解耦:
/// - 网络探测结果经 `apply(result:kernel:)` 注入(刷新由 `onReady` 异步驱动,此处不测网络)。
/// - `evaluate(kernel:)` 同步读 `phase`:仅 `ready` 返回全部 7 个 sub-agent。
///
/// 因此测试聚焦状态机:用 `apply` / `setPhaseForTesting` 注入确定性状态,
/// 不依赖真实网络或 KernelLumi 运行时(kernel 仅在「进入 ready 触发 rebuild」时用到,
/// 该副作用不在本套件验证范围 —— `unknown` → `ready` 不会在此触发,因为测试不构造 kernel)。
@MainActor
@Suite struct StepFunSubAgentsGateTests {

    private func makeGate() -> StepFunSubAgentsGate {
        StepFunSubAgentsGate(provider: StepFunProvider())
    }

    /// 空内核:`toolManager` 为 nil,故 `rebuildAllContributions` 是 no-op,
    /// 可安全用于触发「unknown → ready」的重建路径,无需真实服务装配。
    private let kernel = KernelLumi()

    // MARK: - evaluate:默认 / gate 行为

    @Test func evaluate_returnsEmpty_whenUnknown() {
        let gate = makeGate()
        #expect(gate.phase == .unknown)
        #expect(gate.evaluate().isEmpty,
                "未探测完成(unknown)应保守 gate,返回空")
    }

    @Test func evaluate_returnsAll_whenReady() {
        let gate = makeGate()
        gate.setPhaseForTesting(.ready)

        let subAgents = gate.evaluate()
        #expect(subAgents.count == 7, "ready 时应注册全部 7 个 sub-agent")
        #expect(subAgents.map(\.id).sorted() == [
            "bug-fixer", "builder", "code-reviewer", "doc-writer",
            "explore", "git-commit-writer", "test-writer",
        ])
        // 子 Agent 必须绑定到 StepFun provider,这是 gate 存在的前提。
        #expect(subAgents.allSatisfy { $0.providerID == "stepfun" })
    }

    @Test func evaluate_returnsEmpty_whenUnavailable() {
        let gate = makeGate()
        gate.setPhaseForTesting(.unavailable)
        #expect(gate.evaluate().isEmpty,
                "探测失败(unavailable)必须 gate")
    }

    // MARK: - apply:状态转移(不触发 rebuild,因测试不构造 kernel)

    @Test func apply_transitionsToReady_onAvailable() {
        let gate = makeGate()
        #expect(gate.phase == .unknown)

        // 注意:不传真实 kernel,因此 unknown → ready 会调用
        // kernel.pluginManager.rebuildAllContributions(in:)。为避免依赖运行时,
        // 这里通过一个「已被探测过(unavailable)→ available」的路径,
        // 该路径不触发重建(仅 unknown→ready 才触发),从而安全验证状态转移。
        gate.setPhaseForTesting(.unavailable)
        gate.apply(result: .available, kernel: kernel)
        #expect(gate.phase == .ready,
                "available 结果应将状态推进到 ready")
    }

    @Test func apply_transitionsToUnavailable_onUnavailable() {
        let gate = makeGate()
        gate.apply(result: .unavailable(LumiLLMFailureDetail.message("network down")),
                   kernel: kernel)
        #expect(gate.phase == .unavailable,
                "unavailable 结果应将状态推进到 unavailable")
    }

    @Test func apply_isIdempotent_whenAlreadyReady() {
        let gate = makeGate()
        gate.setPhaseForTesting(.unavailable) // 避开 unknown→ready 的重建副作用
        gate.apply(result: .available, kernel: kernel)
        #expect(gate.phase == .ready)

        // 再次 apply available,状态保持 ready。
        gate.apply(result: .available, kernel: kernel)
        #expect(gate.phase == .ready)
    }

    // MARK: - allDefinitions:静态契约

    @Test func allDefinitions_isCompleteAndStable() {
        let ids = StepFunSubAgentsGate.allDefinitions.map(\.id)
        #expect(ids.count == 7, "全部 sub-agent 定义必须完整")
        #expect(Set(ids).count == 7, "sub-agent id 不得重复")
    }

    // MARK: - 探测模型契约

    @Test func probeModel_matchesSubAgentDefinitions() {
        // gate 探测的模型应与 sub-agent 实际使用的模型一致,
        // 否则「探测通过」不能保证 sub-agent 真的可用。
        let probeModel = StepFunSubAgentsGate.probeModelID
        #expect(StepFunSubAgentsGate.allDefinitions.allSatisfy { $0.modelID == probeModel },
                "所有 sub-agent 必须使用探测模型 \(probeModel),否则探测结果不具代表性")
    }
}
