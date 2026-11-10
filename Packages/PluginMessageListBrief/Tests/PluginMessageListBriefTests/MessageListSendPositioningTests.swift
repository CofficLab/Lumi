import CoreGraphics
import Testing
@testable import PluginMessageListBrief

struct MessageListSendPositioningTests {
    @Test("流式回合使用与内容高度无关的稳定尾部留白")
    func conservativeReserveIsStable() {
        #expect(
            MessageListSendPositioning.conservativeTailReserve(viewportHeight: 800) == 600
        )
        #expect(
            MessageListSendPositioning.conservativeTailReserve(viewportHeight: .nan) == 0
        )
    }

    // MARK: - 发送后定位生命周期（#894）

    /// 回归 #894：首条 assistant 消息产生前停止请求时，pending 回合的
    /// `acceptsLiveActivity` 恒为 true，turn 投影不会变化；若只等 turn
    /// 生命周期复位，尾部留白会一直留到切换会话。活动状态清空是取消路径
    /// 唯一的可观察信号。
    @Test("首条助手消息前取消：活动清空必须结束发送后定位（回归 #894）")
    func cancelBeforeFirstAssistantEndsPostSendPositioning() {
        var state = PostSendPositioningState()
        state.begin(activityIsPresent: true)
        #expect(state.isActive)

        // 取消前 turn 投影仍是 pending，始终接收实时活动。
        let endedByTurns = state.handleTurns(hasLiveTurn: true)
        #expect(!endedByTurns)
        #expect(state.isActive, "取消前不得提前结束定位")

        // 用户点击停止 → 活动清空。
        let endedByActivity = state.handleActivity(isPresent: false)
        #expect(endedByActivity, "活动清空必须结束发送后定位")
        #expect(!state.isActive)
    }

    /// 正常回合结束时 turn 投影不再接收实时活动，定位仍要结束（原有行为）。
    @Test("回合投影去掉实时活动时必须结束发送后定位")
    func liveTurnEndingEndsPostSendPositioning() {
        var state = PostSendPositioningState()
        state.begin(activityIsPresent: true)

        let ended = state.handleTurns(hasLiveTurn: false)
        #expect(ended)
        #expect(!state.isActive)
    }

    /// 插入用户消息与 `startTurn` 之间活动可能尚未出现；此时清空事件
    /// 不能当成回合收尾，否则发送后定位会被立刻撤掉。
    @Test("活动从未出现前的清空不算回合收尾")
    func activityClearingWithoutObservedActivityKeepsPositioning() {
        var state = PostSendPositioningState()
        state.begin(activityIsPresent: false)

        let endedWhileNotStarted = state.handleActivity(isPresent: false)
        #expect(!endedWhileNotStarted)
        #expect(state.isActive)

        // 回合真正启动后，活动先出现，再消失才算收尾。
        let endedOnStart = state.handleActivity(isPresent: true)
        #expect(!endedOnStart)
        #expect(state.isActive)
        let endedAfterStart = state.handleActivity(isPresent: false)
        #expect(endedAfterStart)
        #expect(!state.isActive)
    }

    /// 回合运行期间活动阶段会连续变化（发送 → 思考 → 生成），不能结束定位。
    @Test("回合运行中的活动变化保持定位")
    func activityChangesWhileTurnRunsKeepPositioning() {
        var state = PostSendPositioningState()
        state.begin(activityIsPresent: true)

        let firstChange = state.handleActivity(isPresent: true)
        let secondChange = state.handleActivity(isPresent: true)
        #expect(!firstChange)
        #expect(!secondChange)
        #expect(state.isActive)
    }

    /// 尚未发送时活动变化与定位无关，事件必须被忽略。
    @Test("未开启定位时活动变化不影响状态")
    func activityChangesBeforeSendAreIgnored() {
        var state = PostSendPositioningState()

        let endedByActivity = state.handleActivity(isPresent: true)
        let endedByTurns = state.handleTurns(hasLiveTurn: false)
        #expect(!endedByActivity)
        #expect(!endedByTurns)
        #expect(!state.isActive)
    }

    /// 会话切换与定位收尾都会调用 `end()`，必须可重复调用。
    @Test("结束定位是幂等操作")
    func endIsIdempotent() {
        var state = PostSendPositioningState()
        state.begin(activityIsPresent: true)

        state.end()
        state.end()
        #expect(!state.isActive)
        let endedAfterEnd = state.handleActivity(isPresent: false)
        #expect(!endedAfterEnd)
    }
}
