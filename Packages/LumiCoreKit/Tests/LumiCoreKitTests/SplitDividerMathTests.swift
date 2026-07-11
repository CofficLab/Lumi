import CoreGraphics
import Foundation
import Testing
@testable import LumiCoreKit

@Suite struct SplitDividerMathTests {

    // MARK: - DividerClamp

    @Test func clampPassesThroughValueInRange() {
        let clamp = DividerClamp(totalSize: 800, dividerThickness: 1)
        #expect(clamp.clamp(300) == 300)
    }

    @Test func clampCapsValueAboveMax() {
        let clamp = DividerClamp(totalSize: 800, dividerThickness: 1)
        #expect(clamp.clamp(1000) == 799)
    }

    @Test func clampFloorsNegativeValueToZero() {
        let clamp = DividerClamp(totalSize: 800, dividerThickness: 1)
        #expect(clamp.clamp(-50) == 0)
    }

    @Test func clampMaxPositionIsZeroWhenTotalSizeLeqThickness() {
        // totalSize == thickness：max = max(0, 0) = 0。
        #expect(DividerClamp(totalSize: 8, dividerThickness: 8).maxPosition == 0)
        // totalSize < thickness：max = max(0, 负数) = 0。
        #expect(DividerClamp(totalSize: 4, dividerThickness: 8).maxPosition == 0)
    }

    @Test func clampClampsToZeroWhenTotalSizeLeqThickness() {
        let clamp = DividerClamp(totalSize: 8, dividerThickness: 8)
        #expect(clamp.clamp(500) == 0)
    }

    // MARK: - classifyDividerDrag：状态机分支与顺序

    @Test func firstBaselineWhenNoPreviousSnapshot() {
        // 无基线（prevBounds / prevPosition 为 nil）→ firstBaseline，优先级最高。
        let result = classifyDividerDrag(
            currentBounds: CGSize(width: 800, height: 600),
            currentPosition: 300,
            prevBounds: nil,
            prevPosition: nil,
            suppressionCount: 0
        )
        #expect(result == .firstBaseline)

        // 即便 prevPosition 有值，只要 prevBounds 为 nil 仍是 firstBaseline。
        let result2 = classifyDividerDrag(
            currentBounds: CGSize(width: 800, height: 600),
            currentPosition: 300,
            prevBounds: nil,
            prevPosition: 300,
            suppressionCount: 0
        )
        #expect(result2 == .firstBaseline)
    }

    @Test func windowResizeWhenBoundsChanged() {
        // 整体尺寸变了 → windowResize（优先级高于 jitter/suppress）。
        let result = classifyDividerDrag(
            currentBounds: CGSize(width: 900, height: 600),
            currentPosition: 300,
            prevBounds: CGSize(width: 800, height: 600),
            prevPosition: 300,
            suppressionCount: 0
        )
        #expect(result == .windowResize)
    }

    @Test func windowResizeTakesPrecedenceOverSuppression() {
        // 尺寸变 + 处于抑制窗口 → 仍是 windowResize（resize 优先级高于 suppress）。
        let result = classifyDividerDrag(
            currentBounds: CGSize(width: 900, height: 600),
            currentPosition: 300,
            prevBounds: CGSize(width: 800, height: 600),
            prevPosition: 300,
            suppressionCount: 3
        )
        #expect(result == .windowResize)
    }

    @Test func jitterWhenPositionDeltaBelowThreshold() {
        // 尺寸不变，位移 0.3 < 0.5 → jitter。
        let result = classifyDividerDrag(
            currentBounds: CGSize(width: 800, height: 600),
            currentPosition: 300.3,
            prevBounds: CGSize(width: 800, height: 600),
            prevPosition: 300,
            suppressionCount: 0
        )
        #expect(result == .jitter)
    }

    @Test func jitterThresholdBoundaryIsExclusive() {
        // delta 恰好 0.5：abs(0.5) < 0.5 为 false → 不是 jitter → dragConfirmed。
        let atBoundary = classifyDividerDrag(
            currentBounds: CGSize(width: 800, height: 600),
            currentPosition: 300.5,
            prevBounds: CGSize(width: 800, height: 600),
            prevPosition: 300,
            suppressionCount: 0
        )
        #expect(atBoundary == .dragConfirmed(position: 300.5))

        // delta 0.49：< 0.5 → jitter。
        let justBelow = classifyDividerDrag(
            currentBounds: CGSize(width: 800, height: 600),
            currentPosition: 300.49,
            prevBounds: CGSize(width: 800, height: 600),
            prevPosition: 300,
            suppressionCount: 0
        )
        #expect(justBelow == .jitter)
    }

    @Test func suppressedWhenWithinSuppressionWindow() {
        // 尺寸不变、位移超过阈值、处于抑制窗口 → suppressed（不持久化）。
        let result = classifyDividerDrag(
            currentBounds: CGSize(width: 800, height: 600),
            currentPosition: 400,
            prevBounds: CGSize(width: 800, height: 600),
            prevPosition: 300,
            suppressionCount: 2
        )
        #expect(result == .suppressed)
    }

    @Test func dragConfirmedWhenEverythingAligns() {
        // 尺寸不变、位移超阈值、不在抑制窗口 → dragConfirmed。
        let result = classifyDividerDrag(
            currentBounds: CGSize(width: 800, height: 600),
            currentPosition: 450,
            prevBounds: CGSize(width: 800, height: 600),
            prevPosition: 300,
            suppressionCount: 0
        )
        #expect(result == .dragConfirmed(position: 450))
    }

    @Test func dragConfirmedForNegativeDelta() {
        // 往左拖（位移为负）同样应识别为拖拽。
        let result = classifyDividerDrag(
            currentBounds: CGSize(width: 800, height: 600),
            currentPosition: 200,
            prevBounds: CGSize(width: 800, height: 600),
            prevPosition: 300,
            suppressionCount: 0
        )
        #expect(result == .dragConfirmed(position: 200))
    }

    @Test func customJitterThreshold() {
        // 自定义阈值：位移 2 在默认 0.5 阈值下是 drag，在阈值 5 下是 jitter。
        let withLargeThreshold = classifyDividerDrag(
            currentBounds: CGSize(width: 800, height: 600),
            currentPosition: 302,
            prevBounds: CGSize(width: 800, height: 600),
            prevPosition: 300,
            suppressionCount: 0,
            jitterThreshold: 5
        )
        #expect(withLargeThreshold == .jitter)
    }

    // MARK: - shouldReapplyDivider

    @Test func shouldNotReapplyWhenPositionsEqual() {
        #expect(shouldReapplyDivider(current: 300, saved: 300) == false)
    }

    @Test func shouldNotReapplyAtExactTolerance() {
        // 容差为严格大于：差值恰好等于 tolerance(1) → false。
        #expect(shouldReapplyDivider(current: 301, saved: 300) == false)
        #expect(shouldReapplyDivider(current: 299, saved: 300) == false)
    }

    @Test func shouldReapplyWhenDivergenceExceedsTolerance() {
        // 差值 1.01 > 1 → true。
        #expect(shouldReapplyDivider(current: 301.01, saved: 300) == true)
    }

    @Test func shouldReapplyWithCustomTolerance() {
        #expect(shouldReapplyDivider(current: 305, saved: 300, tolerance: 10) == false)
        #expect(shouldReapplyDivider(current: 311, saved: 300, tolerance: 10) == true)
    }

    // MARK: - dividerPositionValue

    @Test func dividerPositionValueReturnsPaneMaxForValidIndex() {
        #expect(dividerPositionValue(index: 0, count: 2, paneMax: 240, isVertical: true) == 240)
    }

    @Test func dividerPositionValueReturnsZeroForOutOfRangeIndex() {
        // 负下标。
        #expect(dividerPositionValue(index: -1, count: 2, paneMax: 240, isVertical: true) == 0)
        // 下标 == count（越界）。
        #expect(dividerPositionValue(index: 2, count: 2, paneMax: 240, isVertical: true) == 0)
        // 空集合。
        #expect(dividerPositionValue(index: 0, count: 0, paneMax: 240, isVertical: true) == 0)
    }
}
