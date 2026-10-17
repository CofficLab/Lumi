import CoreGraphics
import Foundation
import Testing
@testable import PluginMessageListDetailed

@Suite("底部边缘判定")
@MainActor
struct BottomEdgeEvaluatorTests {

    @Test("文档底沿正好贴合视口底时判定为在底部")
    func flushBottomIsAtBottom() {
        let evaluator = BottomEdgeEvaluator()

        let result = evaluator.evaluate(
            documentHeight: 1000,
            visibleHeight: 400,
            offsetY: 600,
            previousAtBottom: true
        )

        #expect(result?.atBottom == true)
        #expect(result?.shouldNotify == false)
    }

    @Test("远离底部且上次不在底部时不触发回调")
    func farFromBottomDoesNotNotify() {
        let evaluator = BottomEdgeEvaluator()

        let result = evaluator.evaluate(
            documentHeight: 1000,
            visibleHeight: 400,
            offsetY: 0,
            previousAtBottom: false
        )

        #expect(result?.atBottom == false)
        #expect(result?.shouldNotify == false)
    }

    @Test("迟滞：上次在底部时用宽容的离开阈值")
    func hysteresisUsesLeaveToleranceWhenPreviouslyAtBottom() {
        let evaluator = BottomEdgeEvaluator(enterTolerance: 24, leaveTolerance: 96)

        // distance = 1000 - (820 + 100) = 80，未超过离开阈值 96，仍算在底部。
        let staying = evaluator.evaluate(
            documentHeight: 1000,
            visibleHeight: 100,
            offsetY: 820,
            previousAtBottom: true
        )
        // 同一几何但上次不在底部，进入阈值 24 会被判为离开底部。
        let leaving = evaluator.evaluate(
            documentHeight: 1000,
            visibleHeight: 100,
            offsetY: 820,
            previousAtBottom: false
        )

        #expect(staying?.atBottom == true)
        #expect(staying?.shouldNotify == false)
        #expect(leaving?.atBottom == false)
        #expect(leaving?.shouldNotify == false)
    }

    @Test("迟滞：真正越过后翻转并触发回调")
    func crossingToleranceFlipsAndNotifies() {
        let evaluator = BottomEdgeEvaluator(enterTolerance: 24, leaveTolerance: 96)

        // distance = 1000 - (800 + 100) = 100 > 96，上次在底部 → 离开。
        let result = evaluator.evaluate(
            documentHeight: 1000,
            visibleHeight: 100,
            offsetY: 800,
            previousAtBottom: true
        )

        #expect(result?.atBottom == false)
        #expect(result?.shouldNotify == true)
    }

    @Test("回到容差内时重新翻转回在底部并触发回调")
    func returningWithinToleranceNotifies() {
        let evaluator = BottomEdgeEvaluator(enterTolerance: 24, leaveTolerance: 96)

        let result = evaluator.evaluate(
            documentHeight: 1000,
            visibleHeight: 100,
            offsetY: 900,
            previousAtBottom: false
        )

        #expect(result?.atBottom == true)
        #expect(result?.shouldNotify == true)
    }

    @Test(
        "几何退化时返回 nil，调用方保持原状态",
        arguments: [
            (CGFloat.infinity, CGFloat(100), CGFloat(0)),
            (CGFloat(1000), CGFloat.infinity, CGFloat(0)),
            (CGFloat(1000), CGFloat(0), CGFloat(0)),
            (CGFloat(10_000_000), CGFloat(100), CGFloat(0)),
            (CGFloat.nan, CGFloat(100), CGFloat(0))
        ]
    )
    func degenerateGeometryReturnsNil(
        documentHeight: CGFloat,
        visibleHeight: CGFloat,
        offsetY: CGFloat
    ) {
        let evaluator = BottomEdgeEvaluator()

        let result = evaluator.evaluate(
            documentHeight: documentHeight,
            visibleHeight: visibleHeight,
            offsetY: offsetY,
            previousAtBottom: true
        )

        #expect(result == nil)
    }

    @Test("可视高度大于文档高度时视为在底部")
    func visibleTallerThanDocumentIsAtBottom() {
        let evaluator = BottomEdgeEvaluator()

        let result = evaluator.evaluate(
            documentHeight: 100,
            visibleHeight: 400,
            offsetY: 0,
            previousAtBottom: false
        )

        #expect(result?.atBottom == true)
        #expect(result?.shouldNotify == true)
    }

    @Test("默认阈值取自滚动协调器的迟滞常量")
    func defaultTolerancesMatchCoordinatorConstants() {
        let evaluator = BottomEdgeEvaluator()

        #expect(evaluator.enterTolerance == MessageListScrollCoordinator.bottomEnterTolerance)
        #expect(evaluator.leaveTolerance == MessageListScrollCoordinator.bottomLeaveTolerance)
    }
}
