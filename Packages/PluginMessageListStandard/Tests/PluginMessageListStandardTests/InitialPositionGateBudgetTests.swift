import Foundation
import Testing
@testable import PluginMessageListStandard

/// `InitialPositionGate` 的**兜底预算语义**回归测试。
///
/// ## 复现的缺陷
///
/// 首屏遮罩的兜底预算（生产值 3 秒）本该是「从发起首屏定位那一刻起算的
/// 绝对期限」。但实现里，竞速的两条支路都挂在 MainActor 上：
///
/// ```swift
/// settleTask  = Task { @MainActor in … await settle() … }
/// timeoutTask = Task { @MainActor in … Task.sleep(budget) … }
/// ```
///
/// 而 `request` 本身也是通过一个 MainActor 任务去跑这段竞速的。于是当主线程
/// 被占用（富文本排版、其它插件的同步工作）时：
///
/// - 竞速任务**根本没机会启动** → 预算倒计时尚未开始；
/// - 主线程一空闲，预算才开始倒数 → 又要再等一整个预算。
///
/// 结果是遮罩的释放时间 = **主线程占用时长 + 完整预算**，而不是
/// max(主线程占用时长, 预算)。预算从「兜底上限」退化成「额外附加的延迟」。
///
/// ## 为什么这条会影响用户
///
/// 遮罩的显示条件是 `viewModel.isLoading || !initialPositionGate.isReady`。
/// 预算越晚到期，遮罩就多挂那么久 —— 而遮罩一旦撤不掉，用户看到的就是
/// 「切换对话时消息列表一直转圈」。
///
/// ## 采样策略
///
/// 墙钟类断言一律取 **多次采样的中位数**（与 `InitialPositionGateTimingTests`
/// 的既定策略一致）：单次采样会把「机器当时忙」直接算进延迟里。
@MainActor
private func waitUntil(
    _ condition: @MainActor () -> Bool,
    timeoutMs: Int
) async -> Bool {
    for _ in 0..<max(1, timeoutMs / 10) {
        if condition() { return true }
        try? await Task.sleep(nanoseconds: 10_000_000)
    }
    return condition()
}

/// 占用主线程指定时长，返回实际占用秒数。
///
/// - Note: 用同步睡眠而不是 `await Task.sleep` —— 后者会让出 MainActor，
///   起不到「占住」的作用。
@MainActor
private func blockMainActor(seconds: Double) -> Double {
    let start = DispatchTime.now().uptimeNanoseconds
    Thread.sleep(forTimeInterval: seconds)
    return Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000_000
}

@MainActor
@Test("首屏遮罩：兜底预算是绝对期限，主线程被占用时不得再叠加一个完整预算")
func gateBudgetIsAbsoluteNotAdditiveUnderMainActorContention() async {
    // 预算远小于阻塞时长：阻塞结束时预算必然已经耗尽。
    let budget: UInt64 = 500_000_000   // 500ms
    let budgetSeconds = Double(budget) / 1_000_000_000
    let blockSeconds = 0.8
    let samples = 5

    var extras: [Double] = []
    for _ in 0..<samples {
        let gate = InitialPositionGate(budgetNanoseconds: budget)
        let start = DispatchTime.now().uptimeNanoseconds

        gate.request(
            conversationID: UUID(),
            // 收敛永不返回：唯一能放行的就是预算兜底。
            settle: {
                while true {
                    try? await Task.sleep(nanoseconds: 50_000_000)
                }
            },
            stillRelevant: { true }
        )

        // 立刻占住主线程。注意这里**不 await** —— 竞速任务因此完全没能启动，
        // 预算倒计时也还没开始。
        let blocked = blockMainActor(seconds: blockSeconds)

        let ready = await waitUntil({ gate.isReady }, timeoutMs: 3_000)
        let total = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000_000

        #expect(ready, "主线程恢复后兜底必须放行，遮罩不能永久挂起")
        // 只关心「超出阻塞时长的那部分」：预算若在阻塞期间就已耗尽，
        // 恢复后应当立即放行，不该再等一个完整预算。
        extras.append(total - blocked)
    }

    extras.sort()
    let median = extras[extras.count / 2]

    #expect(
        median < budgetSeconds * 0.5,
        """
        主线程被占用 \(blockSeconds)s 后，遮罩又多挂了 \(Int(median * 1000))ms。
        兜底预算应当是绝对期限（阻塞期间就已耗尽，恢复即放行），
        而不是「阻塞时长 + 完整预算」的附加延迟。
        """
    )
}
