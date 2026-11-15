import AppKit
import CoreGraphics
import Testing
@testable import PluginChatScreenshot

/// 拖选时仅重绘可见选区交集实际变化的屏幕（见 issue #1266）。
///
/// `updateSelectionRect` 返回是否触发重绘；无窗口的 NSView 其 `needsDisplay`
/// 读值不可靠，故以返回值断言判定逻辑。
@Suite("Chat Screenshot 遮罩拖选重绘")
@MainActor
struct ChatScreenshotOverlayInvalidationTests {

    @Test("选区不与本屏相交时不触发重绘")
    func nonIntersectingSelectionDoesNotInvalidate() {
        let view = ChatScreenshotOverlayView(
            screenFrame: CGRect(x: 1000, y: 0, width: 800, height: 600)
        )

        let invalidated = view.updateSelectionRect(CGRect(x: 0, y: 0, width: 100, height: 100))

        #expect(invalidated == false)
        #expect(view.localSelectionRect == nil)
    }

    @Test("选区与本屏相交时触发重绘")
    func intersectingSelectionInvalidates() {
        let view = ChatScreenshotOverlayView(
            screenFrame: CGRect(x: 0, y: 0, width: 800, height: 600)
        )

        let invalidated = view.updateSelectionRect(CGRect(x: 10, y: 10, width: 100, height: 100))

        #expect(invalidated == true)
        #expect(view.localSelectionRect != nil)
    }

    @Test("交集保持为空的连续拖动不重复触发重绘")
    func unchangedEmptyIntersectionDoesNotReinvalidate() {
        let view = ChatScreenshotOverlayView(
            screenFrame: CGRect(x: 1000, y: 0, width: 800, height: 600)
        )
        #expect(view.updateSelectionRect(CGRect(x: 0, y: 0, width: 100, height: 100)) == false)

        // 连续拖动仍不与本屏相交：交集始终为空，不应反复重绘全屏遮罩。
        #expect(view.updateSelectionRect(CGRect(x: 0, y: 0, width: 200, height: 150)) == false)
        #expect(view.updateSelectionRect(CGRect(x: 0, y: 0, width: 300, height: 200)) == false)
    }

    @Test("选区离开本屏后交集变化触发一次重绘")
    func intersectionBecomingEmptyInvalidatesOnce() {
        let view = ChatScreenshotOverlayView(
            screenFrame: CGRect(x: 0, y: 0, width: 800, height: 600)
        )
        #expect(view.updateSelectionRect(CGRect(x: 10, y: 10, width: 100, height: 100)) == true)

        // 选区移到另一屏：本屏交集由非空变空，需要重绘以清除旧高亮。
        let invalidated = view.updateSelectionRect(CGRect(x: 1000, y: 0, width: 100, height: 100))

        #expect(invalidated == true)
        #expect(view.localSelectionRect == nil)
    }
}