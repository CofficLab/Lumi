import Foundation
import Testing
@testable import PluginMessageListStandard

/// `InitialPositionGate` 的**时序**回归测试。
///
/// ## 为什么单独成文件
///
/// 首屏遮罩（`isLoading || !initialPositionGate.isReady`）的用户症状是
/// 「切换对话时消息列表出现很慢」。这个症状**只由时间**决定，
/// `InitialPositionGateTests` 断言的是布尔终态，无法区分
/// 「3 秒后放行」与「10 毫秒后放行」—— 后者才是好体验。
///
/// ## 为什么全部用中位数而不是单次取值
///
/// 这类断言测的是墙钟时间，会被系统调度抖动污染。实测同一份**正确**实现
/// 在 8 次连续运行中会红 1 次（单次采样轻易冲到数百毫秒）。
/// 因此：
/// - 每个「放行有多快」都取 **7 次采样的中位数**；
/// - 阈值取回归态与修复态之间的数量级中点（见 `immediateReleaseUpperBound`）。
///
/// 单次取值 + 紧阈值 = 随机测试。它会在 CI 上偶发变红，把所有人的注意力
/// 引向「哪里又坏了」，而真正的原因只是机器当时忙。
@MainActor
private func medianReadyLatencyMs(
    samples: Int = 7,
    _ makeGate: () -> InitialPositionGate
) async -> Double? {
    var values: [Double] = []
    for _ in 0..<samples {
        let gate = makeGate()
        if let latency = await measureReadyLatencyMs(gate) {
            values.append(latency)
        }
    }
    guard !values.isEmpty else { return nil }
    values.sort()
    return values[values.count / 2]
}

@MainActor
private func measureReadyLatencyMs(
    _ gate: InitialPositionGate,
    limitMs: Int = 3_000
) async -> Double? {
    let start = DispatchTime.now().uptimeNanoseconds
    for _ in 0..<(limitMs / 5) {
        if gate.isReady { return elapsedMs(since: start) }
        try? await Task.sleep(nanoseconds: 5_000_000)
    }
    return gate.isReady ? elapsedMs(since: start) : nil
}

@MainActor
private func elapsedMs(since start: UInt64) -> Double {
    Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
}

/// 「收敛已结束 → 必须立即放行」的可接受耗时上界。
///
/// 取 750ms：回归态是 ≈3000ms（无条件等满预算），修复态是亚毫秒级。
/// 阈值落在两者之间且远离两端，因此既能抓住真实回归，又能吸收 CI 负载波动。
private let immediateReleaseUpperBound: Double = 750

// MARK: - 核心回归：成功路径不得被预算拖住

/// 收敛**立刻成功**时，遮罩必须几乎立刻消失，而不是等满整个预算。
///
/// - Important: 这是「切换对话时列表出现很慢」的直接根因。
///   曾经的实现无条件 `await timeout.value`（等满 `budgetNanoseconds`
///   才去取收敛结果），于是**无论几何多稳定，一次切换都要等满 3 秒**。
///   原有的单元测试只断言「最终就绪」，于是 3 秒的行为一直被视为正确。
///
///   正确语义是竞速：收敛成功 → 立即放行；只有收敛**真的不收敛**才等预算兜底。
@MainActor
@Test("首屏遮罩：收敛成功时立即放行，不等满预算")
func gateReleasesImmediatelyWhenSettleSucceeds() async {
    let measured = try! #require(
        await medianReadyLatencyMs {
            let gate = InitialPositionGate(budgetNanoseconds: 3_000_000_000)
            gate.request(conversationID: UUID(), settle: { true }, stillRelevant: { true })
            return gate
        }
    )
    #expect(
        measured < immediateReleaseUpperBound,
        "收敛成功却等了 \(Int(measured))ms（中位数），不该等满 3s 预算"
    )
}

/// 收敛**立刻失败**同样必须立即放行（遮罩不该为已知失败继续遮挡）。
///
/// 与上一条对照，共同锁死「收敛结果完全被忽略」这一行为。
@MainActor
@Test("首屏遮罩：收敛失败时立即放行，不等满预算")
func gateReleasesImmediatelyWhenSettleFails() async {
    let measured = try! #require(
        await medianReadyLatencyMs {
            let gate = InitialPositionGate(budgetNanoseconds: 3_000_000_000)
            gate.request(conversationID: UUID(), settle: { false }, stillRelevant: { true })
            return gate
        }
    )
    #expect(
        measured < immediateReleaseUpperBound,
        "收敛失败却等了 \(Int(measured))ms（中位数）才放行，遮罩无谓遮挡用户"
    )
}

/// 成功与失败的放行时长不应有量级差异——直接暴露「结果被忽略」。
@MainActor
@Test("首屏遮罩：成功与失败路径的放行耗时同量级（收敛结果未生效）")
func gateTreatsSuccessAndFailureIdentically() async {
    func medianLatency(settleResult: Bool) async -> Double? {
        await medianReadyLatencyMs {
            let gate = InitialPositionGate(budgetNanoseconds: 3_000_000_000)
            gate.request(conversationID: UUID(), settle: { settleResult }, stillRelevant: { true })
            return gate
        }
    }

    let successLatency = try! #require(await medianLatency(settleResult: true))
    let failureLatency = try! #require(await medianLatency(settleResult: false))

    // 回归态下两者都 ≈3000ms，差约 0；修复后两者都是亚毫秒级，差同样接近 0。
    // 用 `immediateReleaseUpperBound` 作为容差：它远小于 3000ms，不会放过
    // 「一边等满预算、一边立即放行」这种真实回归。
    let gap = abs(successLatency - failureLatency)
    #expect(
        gap < immediateReleaseUpperBound,
        "成功 \(Int(successLatency))ms 与失败 \(Int(failureLatency))ms 相差 \(Int(gap))ms，收敛结果似乎未参与放行判定"
    )
}

// MARK: - 兜底路径：预算仍必须生效

/// 收敛**永不返回**（几何永不收敛）时，预算兜底必须仍在有限时间内放行。
///
/// 这是兜底存在的唯一理由，不能因为修好快速路径就把它一起删掉。
@MainActor
@Test("首屏遮罩：收敛挂死时预算兜底仍在有限时间内放行")
func gateStillReleasesWhenSettleHangs() async {
    let budget: UInt64 = 400_000_000
    let gate = InitialPositionGate(budgetNanoseconds: budget)
    gate.request(
        conversationID: UUID(),
        settle: {
            while true { try? await Task.sleep(nanoseconds: 50_000_000) }
        },
        stillRelevant: { true }
    )

    let latency = try! #require(await measureReadyLatencyMs(gate))
    #expect(latency >= Double(budget / 1_000_000) * 0.8, "兜底不应早于预算放行，实际 \(Int(latency))ms")
    #expect(latency < Double(budget / 1_000_000) * 2.0, "兜底严重超时，实际 \(Int(latency))ms")
}

// MARK: - 竞态：旧轮次不得污染新轮次

/// 切换会话后，上一轮等待醒来时**不得**清掉新轮次的准备中状态。
///
/// - Important: 曾经的实现里，旧轮次在相关性校验失败后无条件写
///   `isPreparing = false`。此刻新轮次仍在收敛，这会把它的门禁提前打开，
///   后续 `request` 因 `isPreparing == false` 而**再启动一轮收敛**——
///   多轮收敛同时驱动同一个 scroll view，恰好制造用户看到的卡顿。
///
///   第二轮的 settle 被刻意做成挂死（只能靠预算兜底结束），确保它在
///   被观察的窗口内确实还在进行中；若 settle 立即返回，第二轮早就自己
///   收尾了，这条断言就测不到「旧轮次干扰新轮次」这一情形。
@MainActor
@Test("首屏遮罩：旧轮次醒来不清掉新轮次的准备状态")
func staleRoundDoesNotClearNewRoundPreparing() async {
    let gate = InitialPositionGate(budgetNanoseconds: 300_000_000)
    let first = UUID()
    let second = UUID()

    // 第一轮立即收敛（它会在自己的竞速里马上结束）。
    gate.request(conversationID: first, settle: { true }, stillRelevant: { true })
    // 第二轮挂死：只有预算兜底能让它结束，因此整个观察窗口内 isPreparing 恒为 true。
    gate.request(
        conversationID: second,
        settle: { while true { try? await Task.sleep(nanoseconds: 20_000_000) } },
        stillRelevant: { true }
    )

    // 让第一轮被作废后彻底过去，确认它没有把第二轮的门禁提前打开。
    try? await Task.sleep(nanoseconds: 60_000_000)
    #expect(
        gate.isPreparing,
        "旧轮次醒来后 isPreparing 应仍为 true（第二轮仍在等预算兜底），否则门禁被提前打开会重复启动收敛"
    )
    #expect(
        gate.awaitingConversationID == second,
        "等待中的会话应仍是第二个会话"
    )
}
