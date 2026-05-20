import CoreGraphics
import Testing
@testable import EditorOverlayKit

@Suite("EditorSurfaceHighlightsOverlayView")
@MainActor
struct EditorSurfaceHighlightsOverlayViewTests {
    @Test("Effective size honors minimum dimensions")
    func effectiveSizeHonorsMinimumDimensions() {
        let size = EditorSurfaceHighlightsOverlayView.effectiveSize(
            rect: CGRect(x: 10, y: 20, width: 1, height: 0.5),
            minimumWidth: 3,
            minimumHeight: 2
        )

        #expect(size == CGSize(width: 3, height: 2))
    }

    @Test("Positive finite rectangles are renderable")
    func positiveFiniteRectanglesAreRenderable() {
        #expect(EditorSurfaceHighlightsOverlayView.isRenderable(
            rect: CGRect(x: 10, y: 20, width: 1, height: 1),
            minimumWidth: 0,
            minimumHeight: 0
        ))

        #expect(EditorSurfaceHighlightsOverlayView.isRenderable(
            rect: CGRect(x: 10, y: 20, width: 0, height: 0),
            minimumWidth: 2,
            minimumHeight: 2
        ))
    }

    @Test("Invalid rectangles are not renderable")
    func invalidRectanglesAreNotRenderable() {
        #expect(!EditorSurfaceHighlightsOverlayView.isRenderable(
            rect: CGRect(x: CGFloat.infinity, y: 20, width: 1, height: 1),
            minimumWidth: 0,
            minimumHeight: 0
        ))

        #expect(!EditorSurfaceHighlightsOverlayView.isRenderable(
            rect: CGRect(x: 10, y: CGFloat.nan, width: 1, height: 1),
            minimumWidth: 0,
            minimumHeight: 0
        ))

        #expect(!EditorSurfaceHighlightsOverlayView.isRenderable(
            rect: CGRect(x: 10, y: 20, width: 0, height: 0),
            minimumWidth: 0,
            minimumHeight: 0
        ))
    }
}
