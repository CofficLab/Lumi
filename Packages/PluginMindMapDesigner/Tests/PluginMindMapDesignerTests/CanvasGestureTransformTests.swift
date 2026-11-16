import CoreGraphics
import Foundation
import Testing
@testable import PluginMindMapDesigner

/// 回归 #326：连续拖拽/缩放须在上一手势结束的基线上累加，不得每次从零覆盖。
@Suite("MindMap 画布手势基线")
struct CanvasGestureTransformTests {

    @Test("缩放在基线上累加而非覆盖")
    func scaleAccumulatesOnBaseline() {
        var transform = CanvasGestureTransform()
        // 第一次手势放大到 2.0 并结束 → 基线提交为 2.0。
        transform.baseScale = transform.scale(magnification: 2.0)
        #expect(transform.baseScale == 2.0)
        // 第二次手势再放大 1.5 → 3.0，而不是被覆盖成 1.5。
        #expect(transform.scale(magnification: 1.5) == 3.0)
    }

    @Test("缩放钳到上下限")
    func scaleIsClamped() {
        var transform = CanvasGestureTransform()
        transform.baseScale = 2.0
        #expect(transform.scale(magnification: 10.0) == CanvasGestureTransform.maxScale)
        #expect(transform.scale(magnification: 0.01) == CanvasGestureTransform.minScale)
    }

    @Test("平移在基线上累加而非覆盖")
    func offsetAccumulatesOnBaseline() {
        var transform = CanvasGestureTransform()
        // 第一次拖拽 (100, 50) 结束 → 基线提交。
        transform.baseOffset = transform.offset(translation: CGSize(width: 100, height: 50))
        #expect(transform.baseOffset == CGSize(width: 100, height: 50))
        // 第二次拖拽 (30, 20) → (130, 70)，而不是被覆盖成 (30, 20)。
        #expect(transform.offset(translation: CGSize(width: 30, height: 20)) == CGSize(width: 130, height: 70))
    }

    @Test("连续两次拖拽保持连续不跳回原点")
    func consecutiveDragsStayContinuous() {
        var transform = CanvasGestureTransform()
        // 手势 1：从原点拖到 (80, 40)，结束提交基线。
        let endOfFirst = transform.offset(translation: CGSize(width: 80, height: 40))
        transform.baseOffset = endOfFirst
        // 手势 2 起始 translation=0 → 应停在手势 1 结束处，不跳回原点。
        #expect(transform.offset(translation: .zero) == endOfFirst)
        // 手势 2 继续拖 (10, -5) → 在基线上累加。
        #expect(transform.offset(translation: CGSize(width: 10, height: -5)) == CGSize(width: 90, height: 35))
    }

    @Test("连续两次缩放保持连续不跳回 1")
    func consecutiveMagnificationsStayContinuous() {
        var transform = CanvasGestureTransform()
        // 手势 1：放大到 1.8，结束提交基线。
        let endOfFirst = transform.scale(magnification: 1.8)
        transform.baseScale = endOfFirst
        // 手势 2 起始 magnification=1 → 应停在手势 1 结束处，不跳回 1。
        #expect(transform.scale(magnification: 1.0) == endOfFirst)
        // 手势 2 继续放大 1.2 → 在基线 1.8 上累加（浮点乘积用容差比较）。
        let second = transform.scale(magnification: 1.2)
        #expect(abs(second - 1.8 * 1.2) < 1e-9)
    }

    @Test("默认基线为单位变换")
    func defaultBaselineIsIdentity() {
        let transform = CanvasGestureTransform()
        #expect(transform.baseScale == 1.0)
        #expect(transform.baseOffset == .zero)
        #expect(transform.scale(magnification: 1.0) == 1.0)
        #expect(transform.offset(translation: .zero) == .zero)
    }
}