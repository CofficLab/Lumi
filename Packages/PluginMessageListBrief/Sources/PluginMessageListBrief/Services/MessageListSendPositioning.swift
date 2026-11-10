import CoreGraphics

/// Geometry used by Brief's post-send conversation positioning.
enum MessageListSendPositioning {
    /// The top of the newly sent turn should land around the upper quarter of
    /// the message-list viewport.
    static let targetTopFraction: CGFloat = 0.25

    /// Conservative reserve used while the live turn and conversation state
    /// are changing size.
    ///
    /// Measuring a streaming List row with a SwiftUI preference feeds every
    /// token-sized change back into List layout. Keep the reserve independent
    /// of row height so the layout has a stable value until the turn finishes.
    static func conservativeTailReserve(viewportHeight: CGFloat) -> CGFloat {
        guard viewportHeight.isFinite, viewportHeight > 0 else { return 0 }
        return viewportHeight * (1 - targetTopFraction)
    }
}

/// Brief 发送后定位的生命周期（#894）。
///
/// 定位在用户消息插入后开启，直到该回合真正收尾。收尾有两种可观察信号：
///
/// 1. turn 投影里不再有接收实时活动的回合（首条 assistant 消息已落库）；
/// 2. 发送后出现过的活动状态被清空（首条 assistant 消息之前取消）。
///
/// 第 2 条是取消路径唯一的信号：pending 回合的 `acceptsLiveActivity` 恒为
/// true，取消不会插入 assistant 消息，也不会重建消息列表，只等第 1 条会把
/// 尾部留白一直留到切换会话。
///
/// `hasObservedActivity` 用来区分「回合还没开始」与「回合已经结束」：
/// 用户消息插入与 `startTurn` 之间活动可能仍为空，此时清空不能算收尾。
struct PostSendPositioningState: Equatable {
    private(set) var isActive = false
    private(set) var hasObservedActivity = false

    mutating func begin(activityIsPresent: Bool) {
        isActive = true
        hasObservedActivity = activityIsPresent
    }

    /// 活动状态变化；返回 true 表示这次变化结束了定位。
    mutating func handleActivity(isPresent: Bool) -> Bool {
        guard isActive else { return false }
        if isPresent {
            hasObservedActivity = true
            return false
        }
        guard hasObservedActivity else { return false }
        end()
        return true
    }

    /// turn 投影变化；返回 true 表示定位结束。
    mutating func handleTurns(hasLiveTurn: Bool) -> Bool {
        guard isActive, !hasLiveTurn else { return false }
        end()
        return true
    }

    mutating func end() {
        isActive = false
        hasObservedActivity = false
    }
}
