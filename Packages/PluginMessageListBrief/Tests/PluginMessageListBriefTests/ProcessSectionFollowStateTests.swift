import Foundation
import Testing
@testable import PluginMessageListBrief

/// 过程折叠区的**贴底跟随状态**。
///
/// 跟随的语义是「终端式」：内容增长时，若用户仍停在底部就跟着往下走；
/// 用户一旦主动上滚就停下来（不打扰阅读），滚回底部后恢复跟随。
///
/// - Note: 真实行为由 AppKit 的两个通知驱动（内容增长 / 用户滚动），
///   渲染级验证见 `ProcessSectionAutoPinRenderTests`。
///   这里锁定的是与之对应的**纯逻辑**部分 —— 跟随开关的语义。
@MainActor
struct ProcessSectionFollowStateTests {
    /// 跟随开关的纯逻辑模型。
    ///
    /// - Note: 与 `BoundedProcessSection` 的 `@State isFollowing` 语义一致。
    struct FollowState: Equatable {
        /// 用户是否仍贴在底部（跟随是否生效）。
        private(set) var isFollowing: Bool

        init(isFollowing: Bool = true) {
            self.isFollowing = isFollowing
        }

        /// 贴底状态变化（由滚动观察器驱动）。
        ///
        /// - Note: 只有**回到**底部才恢复跟随；离开底部由
        ///   `userScrolledAway` 单独处理，避免「刚展开就不在底部」
        ///   被误判成用户上滚。
        mutating func updateAtBottom(_ atBottom: Bool) {
            if atBottom {
                isFollowing = true
            }
        }

        /// 用户主动上滚：打断跟随。
        mutating func userScrolledAway() {
            isFollowing = false
        }

        /// 内容增长时是否应当钉到底部。
        var shouldPinToBottom: Bool {
            isFollowing
        }
    }

    @Test("初始状态跟随底部")
    func followsByDefault() {
        let state = FollowState()
        #expect(state.shouldPinToBottom)
    }

    @Test("用户上滚后不再被拽回底部")
    func stopsFollowingAfterUserScrollsUp() {
        var state = FollowState()
        state.userScrolledAway()
        #expect(
            !state.shouldPinToBottom,
            "用户已上滚，内容增长时不得强制跳回底部"
        )
    }

    @Test("用户滚回底部后恢复跟随")
    func resumesFollowingWhenUserReturnsToBottom() {
        var state = FollowState()
        state.userScrolledAway()
        #expect(!state.shouldPinToBottom)

        state.updateAtBottom(true)
        #expect(state.shouldPinToBottom, "用户滚回底部后应恢复跟随")
    }

    @Test("上滚后再次贴底，跟随恢复")
    func recoversAfterRepeatedInterruptions() {
        var state = FollowState()
        state.userScrolledAway()
        state.updateAtBottom(true)
        state.userScrolledAway()
        #expect(!state.shouldPinToBottom)

        state.updateAtBottom(true)
        #expect(state.shouldPinToBottom)
    }

    @Test("离开底部但未回到底部时，跟随保持关闭")
    func leavingBottomAloneDoesNotResumeFollowing() {
        var state = FollowState()
        state.userScrolledAway()

        // 观察器报告「不在底部」—— 不应恢复跟随。
        state.updateAtBottom(false)
        #expect(!state.shouldPinToBottom)
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
