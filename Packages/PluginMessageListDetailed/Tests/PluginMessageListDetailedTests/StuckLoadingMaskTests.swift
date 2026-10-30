import Foundation
import Testing
@testable import PluginMessageListDetailed

/// 「正在加载消息…」遮罩**卡死**的复现用例。
///
/// ## 用户报告的现象
///
/// 切到某个会话后，消息区一直盖着「正在加载消息…」遮罩：等几十分钟不消失，
/// 换到别的会话也还是在加载。App 本身没有卡死（主线程空闲、数据库查询毫秒级），
/// 说明是**遮罩的状态机停在了「永不结束」的状态**。
///
/// ## 遮罩为什么会永不结束
///
/// 遮罩的显示条件是 `viewModel.isLoading || !initialPositionGate.isReady`。
/// `InitialPositionGate` 负责「首屏定位收敛之后放行遮罩」，它有三条放行路径：
/// 收敛成功、收敛失败、收敛挂死（超预算）。但这三条路径**全部依赖
/// `request()` 被调用过**——而 `request()` 只在「加载结束 / 首屏出现」时触发。
/// 于是有两条「没有任何人在推进遮罩」的悬空路径：
///
/// 1. **兜底没有独立计时器**：遮罩被挂起（加载开始、会话切换复位）之后，
///    如果没有任何一轮收敛被启动，遮罩就永远不会被放行 —— 没有任何兜底。
/// 2. **失效的一轮把门禁焊死**：一轮收敛若因「会话被换掉 / 又进入加载」而失效，
///    它既不置为就绪，也不释放「准备中」标记；此后同一会话的请求会被
///    去重逻辑挡掉，**再没有一轮收敛能启动**，遮罩同样永远不落。
///
/// 本组用例把这两条悬空路径钉死：遮罩的寿命必须有确定上界。
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

// MARK: - 悬空路径 1：兜底必须独立于「收敛是否被启动」

/// 加载开始后，即使**没有任何一轮收敛被启动**，遮罩也必须在预算内落下。
///
/// - Important: 这条正是用户遇到的形态 —— 遮罩挂起后没有任何东西在推进它。
///   兜底若挂在「收敛轮次」上，遮罩就会永远挂起。
@MainActor
@Test("首屏遮罩：加载开始后即使没有收敛轮次，遮罩也必须在预算内落下")
func gateReleasesMaskWithinBudgetWithoutAnySettleRound() async {
    let gate = InitialPositionGate(budgetNanoseconds: 200_000_000)

    gate.resetForLoadingStart()
    #expect(!gate.isReady, "加载开始后遮罩应当是挂起状态")

    let ready = await waitUntil({ gate.isReady }, timeoutMs: 2_000)
    #expect(
        ready,
        """
        加载开始后遮罩挂起，却没有任何兜底计时器在推进它 —— \
        遮罩将永久挂起（用户界面上就是「正在加载消息…」永不消失）。
        """
    )
}

/// 会话切换复位后同样必须有兜底：新一轮收敛可能迟迟不来（加载还没结束、
/// 收敛请求被去重挡掉……），遮罩不能因此无限期挂着。
@MainActor
@Test("首屏遮罩：会话切换复位后即使没有收敛轮次，遮罩也必须在预算内落下")
func gateReleasesMaskWithinBudgetAfterConversationSwitch() async {
    let conversationID = UUID()
    let gate = InitialPositionGate(budgetNanoseconds: 200_000_000)

    gate.request(conversationID: conversationID, settle: { true }, stillRelevant: { true })
    _ = await waitUntil({ gate.isReady })
    #expect(gate.isReady)

    gate.resetForConversationSwitch()
    #expect(!gate.isReady, "切换会话后必须撤销就绪，遮罩才可重新出现")

    let ready = await waitUntil({ gate.isReady }, timeoutMs: 2_000)
    #expect(
        ready,
        """
        会话切换复位后遮罩重新挂起，若新的收敛轮次迟迟不来，遮罩没有任何兜底 ——
        用户切到哪个会话都会一直停在「正在加载消息…」。
        """
    )
}

// MARK: - 悬空路径 2：失效的一轮不得把同会话的门禁焊死

/// 一轮收敛失效之后，同一会话必须能**重新开始一轮**。
///
/// - Important: 失效的一轮（会话被换掉 / 又进入加载）既不置为就绪，
///   也不该把「准备中」标记留在 true —— 否则同会话的后续请求会被去重挡掉，
///   再没有任何一轮收敛能启动，遮罩永远落不下来。
@MainActor
@Test("首屏遮罩：失效的一轮结束后，同一会话必须能重新开始一轮")
func gateAcceptsNewRoundForSameConversationAfterStaleRound() async {
    let conversationID = UUID()
    let gate = InitialPositionGate(budgetNanoseconds: 300_000_000)

    // 第一轮：仍在加载 → 失效（不置为就绪）。
    gate.request(
        conversationID: conversationID,
        settle: { true },
        stillRelevant: { false }
    )
    // 等这一轮真正结束（收敛本身是立即返回的）。
    try? await Task.sleep(nanoseconds: 100_000_000)

    // 第二轮：加载已结束 → 应当被接受，并最终放行遮罩。
    // 机器繁忙时上一轮可能还没收尾，请求会被去重挡掉，因此重试到被接受为止。
    var accepted = false
    for _ in 0..<500 {
        accepted = gate.request(
            conversationID: conversationID,
            settle: { true },
            stillRelevant: { true }
        )
        if accepted { break }
        try? await Task.sleep(nanoseconds: 10_000_000)
    }
    #expect(
        accepted,
        """
        失效的一轮把「准备中」标记留在了 true，同会话的后续请求被去重挡掉 ——
        遮罩再没有任何触发点能落下（切回该会话同样卡住）。
        """
    )

    let ready = await waitUntil({ gate.isReady }, timeoutMs: 5_000)
    #expect(ready, "同会话重新开始一轮后，遮罩必须落下")
}

/// 失效的一轮结束后，遮罩仍必须能被**同会话的新一轮**放行 —— 即便新一轮
/// 自己也会失效，遮罩也只能由兜底放行，不能由「失效的一轮」放行。
@MainActor
@Test("首屏遮罩：失效的一轮不得放行遮罩，但必须允许后续轮次接手")
func gateStaleRoundMustNotReleaseMaskButMustHandOver() async {
    let conversationID = UUID()
    // Important: 预算给足（5s）。本用例要验的是「**失效的一轮**不得放行遮罩」，
    //   而 gate 还有一条独立的兜底计时器（遮罩寿命上界）。预算太短时兜底会
    //   在断言前开火，失败原因就不再是被测机制本身。
    let gate = InitialPositionGate(budgetNanoseconds: 600_000_000_000)

    gate.request(conversationID: conversationID, settle: { true }, stillRelevant: { false })
    // 等这一轮真正结束（`isPreparing` 落回即表示轮次已收尾），而不是睡固定时长：
    // 机器繁忙时固定 sleep 会在轮次结束前就返回，用例结论会飘。
    _ = await waitUntil({ !gate.isPreparing }, timeoutMs: 5_000)
    #expect(!gate.isReady, "失效的一轮不得放行遮罩")

    // 接手的新一轮：机器繁忙时上一轮可能还没收尾，请求会被去重挡掉，
    // 因此这里重试到被接受为止（去重本身正是本组用例要覆盖的语义）。
    var accepted = false
    for _ in 0..<500 {
        accepted = gate.request(conversationID: conversationID, settle: { true }, stillRelevant: { true })
        if accepted { break }
        try? await Task.sleep(nanoseconds: 10_000_000)
    }
    #expect(accepted, "接手的新一轮必须能被接受")
    let ready = await waitUntil({ gate.isReady }, timeoutMs: 5_000)
    #expect(ready, "接手的新一轮必须能放行遮罩")
}
