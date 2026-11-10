import CoreGraphics
import Foundation
import Testing
@testable import PluginMessageListZCode

/// V4（ZCode）滚动所有权 reducer 契约测试。
///
/// 基准是 ZCode 3.15.1 的 `packages/ui/src/v4/timelineScrollAnchor.ts`：
/// 底部容差固定 48px，`following` 表达**用户滚动权**而不是瞬时几何快照，
/// 只有真实用户滚动输入可以改变它。
///
/// - Important: 本 reducer 独立于 V3 的 `BottomEdgeEvaluator`（enter 24 / leave 96），
///   两者互不影响。
@Suite("ZCode 滚动所有权 reducer")
struct ZCodeScrollAnchorTests {

    // MARK: - 底部容差

    @Test("底部容差固定为 48")
    func bottomToleranceIs48() {
        #expect(ZCodeScrollAnchor.bottomTolerance == 48)
    }

    @Test("距底 48 视为在底部")
    func distanceExactly48IsAtBottom() {
        let metrics = makeMetrics(offsetY: 0, visibleHeight: 600, documentHeight: 648)

        #expect(ZCodeScrollAnchor.distanceToBottom(metrics) == 48)
        #expect(ZCodeScrollAnchor.isAtBottom(metrics))
    }

    @Test("距底 48.01 视为离底")
    func distanceJustOver48IsNotAtBottom() {
        let metrics = makeMetrics(offsetY: 0, visibleHeight: 600, documentHeight: 648.01)

        #expect(ZCodeScrollAnchor.distanceToBottom(metrics) > 48)
        #expect(!ZCodeScrollAnchor.isAtBottom(metrics))
    }

    @Test("内容不足一屏时距底为 0")
    func contentShorterThanViewportIsAtBottom() {
        let metrics = makeMetrics(offsetY: 0, visibleHeight: 600, documentHeight: 400)

        #expect(ZCodeScrollAnchor.distanceToBottom(metrics) == 0)
        #expect(ZCodeScrollAnchor.isAtBottom(metrics))
    }

    // MARK: - 用户滚动改变 following

    @Test("用户上滚离底后解除跟随")
    func userScrollAwayDetaches() {
        var anchor = ZCodeScrollAnchor()
        #expect(anchor.following)

        let metrics = makeMetrics(offsetY: 0, visibleHeight: 600, documentHeight: 1200)
        anchor.handleScroll(metrics: metrics, source: .user)

        #expect(!anchor.following)
    }

    @Test("用户滚回 48 内恢复跟随")
    func userScrollBackToBottomResumes() {
        var anchor = ZCodeScrollAnchor()
        anchor.handleScroll(
            metrics: makeMetrics(offsetY: 0, visibleHeight: 600, documentHeight: 1200),
            source: .user
        )
        #expect(!anchor.following)

        anchor.handleScroll(
            metrics: makeMetrics(offsetY: 552, visibleHeight: 600, documentHeight: 1200),
            source: .user
        )

        #expect(anchor.following)
    }

    @Test("程序化滚动不改变 following")
    func programmaticScrollDoesNotChangeFollowing() {
        var anchor = ZCodeScrollAnchor()
        anchor.handleScroll(
            metrics: makeMetrics(offsetY: 0, visibleHeight: 600, documentHeight: 1200),
            source: .user
        )
        #expect(!anchor.following)

        // 程序化贴底不得把用户意图改回跟随。
        anchor.handleScroll(
            metrics: makeMetrics(offsetY: 600, visibleHeight: 600, documentHeight: 1200),
            source: .programmatic
        )

        #expect(!anchor.following)
    }

    @Test("布局变化不改变 following")
    func layoutScrollDoesNotChangeFollowing() {
        var anchor = ZCodeScrollAnchor()

        anchor.handleScroll(
            metrics: makeMetrics(offsetY: 600, visibleHeight: 600, documentHeight: 1200),
            source: .layout
        )

        #expect(anchor.following)
    }

    // MARK: - 内容变化

    @Test("跟随状态下内容增长贴底")
    func followingSticksToBottomOnContentChange() {
        let anchor = ZCodeScrollAnchor()

        #expect(anchor.following)
        #expect(anchor.contentChangeAction() == .stickToBottom)
    }

    @Test("脱离状态下内容增长保持阅读位置")
    func detachedHoldsPositionOnContentChange() {
        var anchor = ZCodeScrollAnchor()
        anchor.handleScroll(
            metrics: makeMetrics(offsetY: 0, visibleHeight: 600, documentHeight: 1200),
            source: .user
        )

        #expect(!anchor.following)
        #expect(anchor.contentChangeAction() == .hold)
    }

    @Test("脱离状态下 resize 不抢滚动")
    func detachedHoldsOnResize() {
        var anchor = ZCodeScrollAnchor()
        anchor.handleScroll(
            metrics: makeMetrics(offsetY: 0, visibleHeight: 600, documentHeight: 1200),
            source: .user
        )

        // 宽度变化引起的高度重算属于 layout 来源。
        anchor.handleScroll(
            metrics: makeMetrics(offsetY: 0, visibleHeight: 600, documentHeight: 1400),
            source: .layout
        )

        #expect(!anchor.following)
        #expect(anchor.contentChangeAction() == .hold)
    }

    @Test("脱离状态下终态折叠不抢滚动")
    func detachedHoldsOnFinalCollapse() {
        var anchor = ZCodeScrollAnchor()
        anchor.handleScroll(
            metrics: makeMetrics(offsetY: 0, visibleHeight: 600, documentHeight: 1200),
            source: .user
        )

        // 折叠导致 document 变矮，同样是 layout 来源。
        anchor.handleScroll(
            metrics: makeMetrics(offsetY: 0, visibleHeight: 600, documentHeight: 900),
            source: .layout
        )

        #expect(!anchor.following)
        #expect(anchor.contentChangeAction() == .hold)
    }

    // MARK: - 回到底部按钮

    @Test("回到底部按钮只在脱离跟随且有内容时显示")
    func backToBottomButtonVisibility() {
        var anchor = ZCodeScrollAnchor()
        #expect(!anchor.shouldShowBackToBottom(rowCount: 10))

        anchor.handleScroll(
            metrics: makeMetrics(offsetY: 0, visibleHeight: 600, documentHeight: 1200),
            source: .user
        )
        #expect(anchor.shouldShowBackToBottom(rowCount: 10))
        // 没有内容时不需要按钮。
        #expect(!anchor.shouldShowBackToBottom(rowCount: 0))

        // 回到底部后按钮隐藏。
        anchor.handleScroll(
            metrics: makeMetrics(offsetY: 600, visibleHeight: 600, documentHeight: 1200),
            source: .user
        )
        #expect(!anchor.shouldShowBackToBottom(rowCount: 10))
    }

    @Test("点击回到底部按钮恢复跟随")
    func backToBottomButtonRestoresFollowing() {
        var anchor = ZCodeScrollAnchor()
        anchor.handleScroll(
            metrics: makeMetrics(offsetY: 0, visibleHeight: 600, documentHeight: 1200),
            source: .user
        )
        #expect(!anchor.following)

        anchor.resumeFollowing()

        #expect(anchor.following)
        #expect(anchor.contentChangeAction() == .stickToBottom)
    }

    // MARK: - 几何健壮性

    @Test("非有限几何不崩溃也不改变状态")
    func nonFiniteGeometryIsIgnored() {
        var anchor = ZCodeScrollAnchor()
        anchor.handleScroll(
            metrics: makeMetrics(offsetY: 0, visibleHeight: 600, documentHeight: 1200),
            source: .user
        )
        #expect(!anchor.following)

        // NaN / infinity / 负高度都不得让状态翻转。
        anchor.handleScroll(
            metrics: makeMetrics(offsetY: .nan, visibleHeight: 600, documentHeight: 1200),
            source: .user
        )
        #expect(!anchor.following)

        anchor.handleScroll(
            metrics: makeMetrics(offsetY: 0, visibleHeight: 600, documentHeight: .infinity),
            source: .user
        )
        #expect(!anchor.following)

        anchor.handleScroll(
            metrics: makeMetrics(offsetY: 0, visibleHeight: -100, documentHeight: 1200),
            source: .user
        )
        #expect(!anchor.following)
    }

    @Test("非有限几何的距离计算返回 0 且不崩溃")
    func nonFiniteDistanceIsZero() {
        let metrics = makeMetrics(offsetY: .nan, visibleHeight: 600, documentHeight: 1200)

        #expect(ZCodeScrollAnchor.distanceToBottom(metrics) == 0)
    }

    // MARK: - 辅助

    private func makeMetrics(
        offsetY: CGFloat,
        visibleHeight: CGFloat,
        documentHeight: CGFloat
    ) -> ZCodeScrollMetrics {
        ZCodeScrollMetrics(
            offsetY: offsetY,
            visibleHeight: visibleHeight,
            documentHeight: documentHeight
        )
    }
}
