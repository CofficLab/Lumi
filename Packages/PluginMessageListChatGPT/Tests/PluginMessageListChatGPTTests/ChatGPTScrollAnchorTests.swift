import CoreGraphics
import Foundation
import Testing
@testable import PluginMessageListChatGPT

/// V5（ChatGPT）滚动所有权 reducer 测试。
///
/// 基准是 V5 方案第 2.7 节与 Task 6 的要求：
/// - 47/48 视为底部，49 脱离；
/// - 只有 `.user` 来源能改变 following；
/// - 用户上滑立即 detached；
/// - delta、文档变高、terminal 折叠、resize 不抢回；
/// - 点击回到底部恢复；用户回到 48 内恢复；
/// - prepend 保持锚点。
@Suite("V5 滚动所有权")
struct ChatGPTScrollAnchorTests {

    private func metrics(
        offsetY: CGFloat,
        visibleHeight: CGFloat = 600,
        documentHeight: CGFloat = 1000,
        direction: ChatGPTUserScrollDirection? = nil
    ) -> ChatGPTScrollMetrics {
        ChatGPTScrollMetrics(
            userDirection: direction,
            offsetY: offsetY,
            visibleHeight: visibleHeight,
            documentHeight: documentHeight
        )
    }

    // MARK: - 底部判定

    @Test("47 与 48 视为底部，49 脱离")
    func bottomToleranceBoundary() {
        // 文档 1000，可视 600 → 底沿在 offset 400，距离 = 400 - offset。
        #expect(ChatGPTScrollAnchor.isAtBottom(metrics(offsetY: 400)))   // 距离 0
        #expect(ChatGPTScrollAnchor.isAtBottom(metrics(offsetY: 352)))   // 距离 48 → 底部
        #expect(!ChatGPTScrollAnchor.isAtBottom(metrics(offsetY: 351)))  // 距离 49 → 脱离
    }

    @Test("容差是 48")
    func toleranceValue() {
        #expect(ChatGPTScrollAnchor.bottomTolerance == 48)
    }

    @Test("内容不足一屏时距离为 0，视为底部")
    func shortContentIsAtBottom() {
        let short = metrics(offsetY: 0, visibleHeight: 600, documentHeight: 300)
        #expect(ChatGPTScrollAnchor.distanceToBottom(short) == 0)
        #expect(ChatGPTScrollAnchor.isAtBottom(short))
    }

    @Test("非法几何不产生负距离")
    func invalidGeometryReturnsZero() {
        for value in [CGFloat.nan, .infinity, -CGFloat.infinity] {
            let invalid = metrics(offsetY: value)
            #expect(ChatGPTScrollAnchor.distanceToBottom(invalid) == 0)
        }
    }

    // MARK: - 来源约束

    @Test("只有 user 来源能改变 following")
    func onlyUserSourceChangesFollowing() {
        var anchor = ChatGPTScrollAnchor()

        // 程序化事件：即使用户已经滚离底部，也不得改变状态。
        anchor.handleScroll(metrics: metrics(offsetY: 0), source: .programmatic)
        #expect(anchor.following)

        // 布局事件（文档变高）同样不改变状态。
        anchor.handleScroll(metrics: metrics(offsetY: 0), source: .layout)
        #expect(anchor.following)
    }

    @Test("用户往回滚立即脱离跟随")
    func userScrollingBackwardDetachesImmediately() {
        var anchor = ChatGPTScrollAnchor()
        #expect(anchor.following)

        anchor.handleScroll(
            metrics: metrics(offsetY: 400, direction: .backward),
            source: .user
        )

        #expect(!anchor.following)
    }

    @Test("用户往回滚方向事件单独也能解除跟随")
    func userDirectionDetachesImmediately() {
        var anchor = ChatGPTScrollAnchor()

        anchor.handleUserScroll(direction: .backward)

        #expect(!anchor.following)
    }

    @Test("用户往前滚不恢复跟随，除非回到 48 内")
    func forwardScrollRestoresOnlyNearBottom() {
        var anchor = ChatGPTScrollAnchor()
        anchor.handleUserScroll(direction: .backward)
        #expect(!anchor.following)

        // 往前滚但离底还远：保持脱离。
        anchor.handleScroll(
            metrics: metrics(offsetY: 100, direction: .forward),
            source: .user
        )
        #expect(!anchor.following)

        // 回到 48 内：恢复跟随。
        anchor.handleScroll(
            metrics: metrics(offsetY: 352, direction: .forward),
            source: .user
        )
        #expect(anchor.following)
    }

    // MARK: - 内容变化

    @Test("脱离后内容变化不抢回跟随")
    func contentChangeDoesNotStealBackFollow() {
        var anchor = ChatGPTScrollAnchor()
        anchor.handleUserScroll(direction: .backward)

        #expect(anchor.contentChangeAction() == .hold)
    }

    @Test("跟随时内容变化贴底")
    func contentChangeSticksToBottomWhenFollowing() {
        let anchor = ChatGPTScrollAnchor()
        #expect(anchor.contentChangeAction() == .stickToBottom)
    }

    // MARK: - 恢复

    @Test("点击回到底部恢复跟随")
    func resumeFollowingRestores() {
        var anchor = ChatGPTScrollAnchor()
        anchor.handleUserScroll(direction: .backward)
        #expect(!anchor.following)

        anchor.resumeFollowing()

        #expect(anchor.following)
    }

    @Test("回到底部按钮只在脱离且有内容时出现")
    func backToBottomButtonVisibility() {
        var anchor = ChatGPTScrollAnchor()
        // 跟随时不出现。
        #expect(!anchor.shouldShowBackToBottom(rowCount: 10))

        anchor.handleUserScroll(direction: .backward)
        // 脱离但没有内容时不出现（没有可回的目标）。
        #expect(!anchor.shouldShowBackToBottom(rowCount: 0))
        // 脱离且有内容时出现。
        #expect(anchor.shouldShowBackToBottom(rowCount: 10))
    }

    // MARK: - 几何退化

    @Test("非有限几何不改变 following")
    func invalidGeometryDoesNotFlipState() {
        var anchor = ChatGPTScrollAnchor()

        anchor.handleScroll(
            metrics: metrics(offsetY: .nan, direction: .backward),
            source: .user
        )

        // 几何不可用时不得翻转状态。
        #expect(anchor.following)
    }
}
