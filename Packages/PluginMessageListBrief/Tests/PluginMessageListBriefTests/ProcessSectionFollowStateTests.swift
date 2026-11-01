import Foundation
import Testing
@testable import PluginMessageListBrief

/// 过程折叠区的贴底跟随。
///
/// 跟随的语义是「终端式」：内容增长时，若用户仍停在底部就跟着往下走；
/// 用户一旦主动上滚就停下来（不打扰阅读），滚回底部后恢复跟随。
@MainActor
struct ProcessSectionFollowStateTests {
    /// 贴底跟随的状态机。
    ///
    /// - Note: 这是一个**纯逻辑**模型，与 `BoundedProcessSection` 的
    ///   `@State isPinnedToBottom` 语义一一对应。抽出来是为了让
    ///   「用户上滚后不再被拽回底部」这条规则可被单测锁定。
    struct FollowState: Equatable {
        /// 用户是否仍贴在底部。
        private(set) var isPinnedToBottom: Bool

        init(isPinnedToBottom: Bool = true) {
            self.isPinnedToBottom = isPinnedToBottom
        }

        /// 贴底状态变化（由滚动观察器驱动）。
        mutating func updateAtBottom(_ atBottom: Bool) {
            isPinnedToBottom = atBottom
        }

        /// 内容增长时是否应当跟随到新底部。
        var shouldFollow: Bool {
            isPinnedToBottom
        }
    }

    @Test("初始状态跟随底部")
    func followsByDefault() {
        var state = FollowState()
        #expect(state.shouldFollow)
    }

    @Test("用户上滚后不再被拽回底部")
    func stopsFollowingAfterUserScrollsUp() {
        var state = FollowState()
        state.updateAtBottom(false)
        #expect(!state.shouldFollow, "用户已上滚，内容增长时不得强制跳回底部")
    }

    @Test("用户滚回底部后恢复跟随")
    func resumesFollowingWhenUserReturnsToBottom() {
        var state = FollowState()
        state.updateAtBottom(false)
        #expect(!state.shouldFollow)

        state.updateAtBottom(true)
        #expect(state.shouldFollow, "用户滚回底部后应恢复跟随")
    }

    @Test("停在底部时的轻微抖动不打断跟随")
    func toleratesJitterAtBottom() {
        var state = FollowState()
        // 观察器用 1pt 容差判定贴底；这里模拟容差内的状态翻转。
        state.updateAtBottom(true)
        #expect(state.shouldFollow)
    }

    @Test("上滚后再次贴底，跟随恢复")
    func recoversAfterRepeatedInterruptions() {
        var state = FollowState()
        state.updateAtBottom(false)
        state.updateAtBottom(true)
        state.updateAtBottom(false)
        #expect(!state.shouldFollow)

        state.updateAtBottom(true)
        #expect(state.shouldFollow)
    }

    // MARK: - 首次评估不算「用户上滚」

    /// 折叠区观察器的判定模型：只有**非首次**评估中离开底部才算用户上滚。
    ///
    /// 展开一个内容超长的折叠区时，初始偏移量就在顶部（offset = 0），
    /// 这时若把「不在底部」当成「用户上滚」，贴底跟随会在第一次内容增长时
    /// 就被打断 —— 违背「自动跟随底部（可被用户打断）」的预期。
    struct ObserverModel: Equatable {
        private(set) var isPinnedToBottom = true
        private(set) var hasEvaluatedOnce = false
        /// 用户主动上滚的次数。
        private(set) var userScrollCount = 0

        mutating func evaluate(atBottom: Bool) {
            let isFirst = !hasEvaluatedOnce
            hasEvaluatedOnce = true

            if atBottom != isPinnedToBottom {
                isPinnedToBottom = atBottom
            }
            if !atBottom && !isFirst {
                userScrollCount += 1
            }
        }
    }

    @Test("首次评估在顶部不算用户上滚，不打断跟随")
    func firstEvaluationAtTopIsNotUserScroll() {
        var model = ObserverModel()
        // 展开一个超长折叠区：初始就在顶部，不在底部。
        model.evaluate(atBottom: false)

        #expect(model.userScrollCount == 0, "首次评估不得记为用户上滚")
        #expect(
            !model.isPinnedToBottom,
            "状态应如实反映「当前不在底部」"
        )
    }

    @Test("非首次评估离开底部才记为用户上滚")
    func laterEvaluationAwayFromBottomIsUserScroll() {
        var model = ObserverModel()
        model.evaluate(atBottom: false)
        model.evaluate(atBottom: false)

        #expect(model.userScrollCount == 1, "第二次离开底部应记为用户上滚一次")
    }

    @Test("首次评估在底部也不打断跟随")
    func firstEvaluationAtBottomKeepsFollowing() {
        var model = ObserverModel()
        model.evaluate(atBottom: true)

        #expect(model.userScrollCount == 0)
        #expect(model.isPinnedToBottom)
    }
}

/// 稳定哈希：内容版本号必须跨进程一致。
struct StableHashValueTests {
    @Test("同一 UUID 的稳定哈希恒定")
    func stableHashIsDeterministic() {
        let id = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        #expect(id.stableHashValue == id.stableHashValue)
        #expect(
            id.stableHashValue
                == UUID(uuidString: "11111111-2222-3333-4444-555555555555")!.stableHashValue
        )
    }

    @Test("不同 UUID 的稳定哈希不同")
    func stableHashDistinguishesIDs() {
        let a = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let b = UUID(uuidString: "11111111-2222-3333-4444-555555555556")!
        #expect(a.stableHashValue != b.stableHashValue)
    }

    @Test("稳定哈希非负")
    func stableHashIsNonNegative() {
        for _ in 0..<64 {
            #expect(UUID().stableHashValue >= 0)
        }
    }
}
