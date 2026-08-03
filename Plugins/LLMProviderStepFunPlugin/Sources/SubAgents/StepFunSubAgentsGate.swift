import Foundation
import LumiKernel

/// StepFun 子 Agent 的可用性 gate。
///
/// 背景：插件可用性探测是异步的，不能阻塞启动流程。
/// (`PluginManager.registerAgentTools`)与插件启停
/// (`PluginManager.rebuildAllContributions`)时各调用一次,且没有事件机制
/// 让插件运行时主动重新收集自己的 sub-agents —— 除非插件自己调用 public 的
/// `kernel.pluginManager.rebuildAllContributions(in:)`。
///
/// 而供应商是否「可用」需要一次异步网络探测(`checkAvailability`,带 5 分钟磁盘缓存)。
/// 两者天然冲突,这里用「同步 gate + 异步探测 + 探测后触发一次重建」化解:
///
/// ```
/// 状态机:  unknown(初始) ──探测通过──▶ ready   → evaluate 返回全部 7 个 sub-agent
///               │
///               └──探测失败──▶ unavailable      → evaluate 返回 [](gate)
///           (unknown 也返回 [],保守 gate)
/// ```
///
/// `onReady` 异步启动探测，探测完成后更新 gate 状态。
/// (已 ready → 返全部)。磁盘缓存命中时,从启动到注册成功的窗口被压到很短。
@MainActor
final class StepFunSubAgentsGate {
    /// 子 Agent 实际依赖的模型(所有 sub-agent 定义都用该模型)。
    static let probeModelID = "step-3.7-flash"

    /// gate 的探测状态。
    enum Phase: Equatable {
        /// 尚未探测完成。保守 gate,`evaluate` 返回空。
        case unknown
        /// 探测通过,供应商可用。`evaluate` 返回全部 sub-agent。
        case ready
        /// 探测失败(网络错误 / 401 / 403 等)。`evaluate` 返回空。
        case unavailable
    }

    /// gate 背后实际做网络探测的 provider。
    private let provider: StepFunProvider

    /// 当前状态。
    private(set) var phase: Phase = .unknown

    /// 防止并发重复探测。
    private var isRefreshing = false

    init(provider: StepFunProvider) {
        self.provider = provider
    }

    // MARK: - Read

    /// gate 对外暴露的全部 sub-agent 定义(按稳定顺序,便于断言)。
    static let allDefinitions: [LumiSubAgentDefinition] = [
        ExploreAgent.definition,
        BuildAgent.definition,
        BugFixerAgent.definition,
        CodeReviewAgent.definition,
        TestWriterAgent.definition,
        DocWriterAgent.definition,
        GitCommitWriterAgent.definition,
    ]

    /// 同步读:仅当 `ready` 时返回全部 sub-agent,其余状态返回空数组。
    ///
    /// gate 决策不触发网络,
    /// 网络探测由 `refresh(kernel:)` 在 `onReady` 异步驱动。
    /// 不需要 kernel(决策纯本地),故签名不带它,便于无 kernel 环境测试。
    func evaluate() -> [LumiSubAgentDefinition] {
        phase == .ready ? Self.allDefinitions : []
    }

    // MARK: - Probe

    /// 异步探测供应商可用性。
    ///
    /// - 复用 `StepFunProvider.checkAvailability` → `AvailabilityService` →
    ///   `AvailabilityDiskCache`(5 分钟磁盘缓存),命中缓存时几乎立即返回。
    /// - 探测结果仅在与上次不同时更新 `phase`,并在 `unknown → ready` 时触发一次
    ///   `rebuildAllContributions`,让框架重新收集此时已就绪的 sub-agent。
    /// - 通过 `probe(result:)` 注入点解耦网络,便于测试。
    func refresh(kernel: LumiKernel) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let result = await provider.checkAvailability(model: Self.probeModelID)
        apply(result: result, kernel: kernel)
    }

    /// 将一次探测结果应用到状态机(测试注入点)。
    ///
    /// 仅当状态发生变化、或从 `unknown` 首次进入 `ready` 时才推进:
    /// - `available` → `ready`(若此前非 ready,触发一次 rebuild)
    /// - `unavailable` → `unavailable`
    func apply(result: LumiModelAvailabilityResult, kernel: LumiKernel) {
        let next: Phase
        switch result {
        case .available:
            next = .ready
        case .unavailable:
            next = .unavailable
        }

        let becameReady = (phase != .ready && next == .ready)
        phase = next

        // 仅在「首次进入 ready」时触发一次全量重建,避免反复 rebuild。
        if becameReady {
            kernel.pluginManager.rebuildAllContributions(in: kernel)
        }
    }

    /// 测试专用:直接置位 phase(绕过网络),便于在不依赖 kernel 的场景断言 evaluate。
    func setPhaseForTesting(_ phase: Phase) {
        self.phase = phase
    }
}
