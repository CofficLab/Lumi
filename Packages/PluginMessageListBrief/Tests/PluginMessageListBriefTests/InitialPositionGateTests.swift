import Foundation
import Testing
@testable import PluginMessageListBrief

/// 首屏就绪兜底（`InitialPositionGate`）的行为不变式。
///
/// ## 为什么 V1 需要它
///
/// V1 曾用裸 `@State` 布尔表达「首屏已定位」，只有「收敛返回 true」一条置真路径。
/// 收敛失败或挂死时遮罩永久挂起，没有任何兜底能救。
///
/// 本组用例锁住兜底契约：**遮罩一定会落下来**，只是早晚。
@MainActor
private func waitUntil(
    _ condition: @MainActor () -> Bool,
    timeoutMs: Int = 2_000
) async -> Bool {
    for _ in 0..<(timeoutMs / 10) {
        if condition() { return true }
        try? await Task.sleep(nanoseconds: 10_000_000)
    }
    return condition()
}

@MainActor
@Test("首屏就绪：收敛成功后放行")
func gateBecomesReadyAfterSuccessfulSettle() async {
    let gate = InitialPositionGate(budgetNanoseconds: 500_000_000)
    let conversationID = UUID()

    gate.request(conversationID: conversationID, settle: { true }, stillRelevant: { true })

    let ready = await waitUntil { gate.isReady }
    #expect(ready, "收敛成功后应就绪")
}

@MainActor
@Test("首屏就绪：收敛失败也在预算内放行，绝不永久卡死")
func gateReleasesEvenWhenSettleFails() async {
    let conversationID = UUID()
    let gate = InitialPositionGate(budgetNanoseconds: 200_000_000)

    // 收敛永远失败（模拟几何不收敛）
    gate.request(conversationID: conversationID, settle: { false }, stillRelevant: { true })

    let ready = await waitUntil({ gate.isReady }, timeoutMs: 2_000)
    #expect(ready, "收敛失败时必须在预算内强制放行，否则遮罩永久挂起")
}

@MainActor
@Test("首屏就绪：收敛挂死时由超时兜底放行")
func gateReleasesWhenSettleHangs() async {
    let conversationID = UUID()
    let gate = InitialPositionGate(budgetNanoseconds: 150_000_000)

    // 收敛永不返回
    gate.request(
        conversationID: conversationID,
        settle: {
            while true {
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
            return false
        },
        stillRelevant: { true }
    )

    let ready = await waitUntil({ gate.isReady }, timeoutMs: 2_000)
    #expect(ready, "收敛挂死时超时兜底必须放行")
}

@MainActor
@Test("首屏就绪：同一会话重复请求被去重")
func gateDeduplicatesSameConversation() async {
    let conversationID = UUID()
    let gate = InitialPositionGate(budgetNanoseconds: 500_000_000)
    var settleCount = 0

    let first = gate.request(
        conversationID: conversationID,
        settle: { settleCount += 1; return true },
        stillRelevant: { true }
    )
    let second = gate.request(
        conversationID: conversationID,
        settle: { settleCount += 1; return true },
        stillRelevant: { true }
    )

    #expect(first)
    #expect(!second, "同会话并发请求应被去重")
    _ = await waitUntil { gate.isReady }
    #expect(settleCount == 1, "收敛只应执行一次")
}

@MainActor
@Test("首屏就绪：切换会话作废上一轮等待，不被旧结果污染")
func gateDiscardsPreviousConversationOnSwitch() async {
    let first = UUID()
    let second = UUID()
    let gate = InitialPositionGate(budgetNanoseconds: 300_000_000)

    // 第一轮挂死
    gate.request(
        conversationID: first,
        settle: {
            try? await Task.sleep(nanoseconds: 400_000_000)
            return false
        },
        stillRelevant: { true }
    )

    // 立刻切到第二个会话
    gate.request(conversationID: second, settle: { true }, stillRelevant: { true })

    let ready = await waitUntil({ gate.isReady })
    #expect(ready, "新会话应正常就绪")
    #expect(gate.awaitingConversationID == nil || gate.awaitingConversationID == second)
}

@MainActor
@Test("首屏就绪：会话切换复位后不再就绪")
func gateResetClearsReady() async {
    let conversationID = UUID()
    let gate = InitialPositionGate(budgetNanoseconds: 200_000_000)

    gate.request(conversationID: conversationID, settle: { true }, stillRelevant: { true })
    _ = await waitUntil { gate.isReady }
    #expect(gate.isReady)

    gate.resetForConversationSwitch()
    #expect(!gate.isReady, "切换会话后必须撤销就绪，遮罩才可重新出现")
}

@MainActor
@Test("首屏就绪：相关性失效时不置为就绪")
func gateIgnoresResultWhenNoLongerRelevant() async {
    let conversationID = UUID()
    // Important: 预算给足（5s）。本用例要验的是「**失效的一轮**不得置为就绪」，
    //   而 gate 现在还有一条独立的兜底计时器（遮罩寿命上界）。预算太短时，
    //   兜底会在断言前开火，失败原因就不再是「失效的一轮放行了遮罩」，
    //   而是被测机制被另一个机制抢跑掩盖了。
    let gate = InitialPositionGate(budgetNanoseconds: 600_000_000_000)

    gate.request(
        conversationID: conversationID,
        settle: { true },
        stillRelevant: { false } // 期间会话被换掉 / 仍在加载
    )

    _ = await waitUntil({ !gate.isPreparing }, timeoutMs: 2_000)
    #expect(!gate.isReady, "已失效的一轮不得置为就绪")
}

@MainActor
@Test("首屏就绪：没有选中会话时直接就绪")
func gateWithoutConversationIsImmediatelyReady() async {
    let gate = InitialPositionGate(budgetNanoseconds: 500_000_000)

    gate.request(conversationID: nil, settle: { false }, stillRelevant: { true })

    #expect(gate.isReady, "无选中会话无需定位")
    #expect(!gate.isPreparing)
}

@MainActor
@Test("首屏遮罩：会话切换的复位不得作废已在当前会话上启动的收敛")
func gateResetMustNotCancelConvergenceAlreadyStarted() async {
    let conversationID = UUID()
    let gate = InitialPositionGate(budgetNanoseconds: 3_000_000_000)

    // 同一 update cycle 内「准备先到、切换复位后到」：收敛已经启动。
    gate.request(
        conversationID: conversationID,
        settle: {
            try? await Task.sleep(nanoseconds: 150_000_000)
            return true
        },
        stillRelevant: { true }
    )

    gate.resetForConversationSwitch()

    let ready = await waitUntil({ gate.isReady }, timeoutMs: 2_000)
    #expect(
        ready,
        """
        复位把已启动的收敛作废后，遮罩再没有触发点能恢复 —— \
        收敛是否还有效本应由它自己的 stillRelevant 判定，而不是由复位无条件取消。
        """
    )
}

@MainActor
@Test("首屏遮罩：复位不得让已失效的旧一轮放行遮罩")
func gateResetMustNotReleaseMaskFromStaleRound() async {
    let staleConversationID = UUID()
    // Important: 预算给足（30s）。本用例要验的是「**失效的一轮**不得放行遮罩」，
    //   而 gate 还有一条独立的兜底计时器（遮罩寿命上界）。预算太短时兜底会
    //   在断言前开火，失败原因就不再是被测机制本身（机器繁忙时 sleep 也会超时）。
    let gate = InitialPositionGate(budgetNanoseconds: 30_000_000_000)

    // 旧会话的一轮仍在飞行，但已经失效（会话已被换掉）。
    gate.request(
        conversationID: staleConversationID,
        settle: {
            try? await Task.sleep(nanoseconds: 120_000_000)
            return true
        },
        stillRelevant: { false }
    )

    gate.resetForConversationSwitch()

    try? await Task.sleep(nanoseconds: 300_000_000)
    #expect(!gate.isReady, "已失效的一轮不得放行遮罩")
}
