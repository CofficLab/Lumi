import SwiftUI
import XCTest
@testable import LumiPreviewKit

@MainActor
final class PreviewSurfaceCanvasTests: XCTestCase {

    func test_init_usesDefaultInteractionAndCallbacks() {
        let canvas = LumiPreviewFacade.PreviewSurfaceCanvas(surfaceID: 123)

        XCTAssertEqual(canvas.surfaceID, 123)
        XCTAssertFalse(canvas.isInteractive)
        XCTAssertEqual(canvas.cursorShape, .arrow)
    }

    func test_init_preservesExplicitPropertiesAndCallbacks() {
        var receivedSize: CGSize?
        var receivedScale: CGFloat?
        var receivedEvent: LumiPreviewFacade.PreviewInputEvent?

        let canvas = LumiPreviewFacade.PreviewSurfaceCanvas(
            surfaceID: 456,
            isInteractive: true,
            cursorShape: .pointingHand,
            onSizeChange: { size, scale in
                receivedSize = size
                receivedScale = scale
            },
            onInputEvent: { event in
                receivedEvent = event
            }
        )

        XCTAssertEqual(canvas.surfaceID, 456)
        XCTAssertTrue(canvas.isInteractive)
        XCTAssertEqual(canvas.cursorShape, .pointingHand)

        canvas.onSizeChange(CGSize(width: 10, height: 20), 2)
        canvas.onInputEvent(.flagsChanged(modifiers: [.command]))

        XCTAssertEqual(receivedSize, CGSize(width: 10, height: 20))
        XCTAssertEqual(receivedScale, 2)
        XCTAssertEqual(receivedEvent, .flagsChanged(modifiers: [.command]))
    }

    func test_configure_attachesSurfaceAndAppliesCallbacksAndInteractionState() throws {
        let frame = try XCTUnwrap(
            LumiPreviewFacade.DemoSurfaceFactory.makeFrame(width: 16, height: 12, scale: 1, seq: 1)
        )
        var receivedSize: CGSize?
        var receivedScale: CGFloat?
        var receivedEvent: LumiPreviewFacade.PreviewInputEvent?
        let canvas = LumiPreviewFacade.PreviewSurfaceCanvas(
            surfaceID: frame.surfaceID,
            isInteractive: true,
            cursorShape: .crosshair,
            onSizeChange: { size, scale in
                receivedSize = size
                receivedScale = scale
            },
            onInputEvent: { event in
                receivedEvent = event
            }
        )
        let view = LumiPreviewFacade.PreviewSurfaceView(frame: NSRect(x: 0, y: 0, width: 16, height: 12))

        canvas.configure(view)

        XCTAssertEqual(view.currentSurfaceID, frame.surfaceID)
        XCTAssertNil(view.layer?.contents)
        XCTAssertNotEqual(view.debugContentLayerFrame, .zero)
        XCTAssertTrue(view.isInteractive)
        XCTAssertEqual(view.cursorShape, .crosshair)

        view.onSizeChange?(CGSize(width: 16, height: 12), 1)
        view.onInputEvent?(.flagsChanged(modifiers: [.shift]))

        XCTAssertEqual(receivedSize, CGSize(width: 16, height: 12))
        XCTAssertEqual(receivedScale, 1)
        XCTAssertEqual(receivedEvent, .flagsChanged(modifiers: [.shift]))
    }

    func test_configure_detachesWhenSurfaceIDIsNil() throws {
        let frame = try XCTUnwrap(
            LumiPreviewFacade.DemoSurfaceFactory.makeFrame(width: 16, height: 12, scale: 1, seq: 1)
        )
        let view = LumiPreviewFacade.PreviewSurfaceView(frame: NSRect(x: 0, y: 0, width: 16, height: 12))
        view.attach(surfaceID: frame.surfaceID)
        XCTAssertEqual(view.currentSurfaceID, frame.surfaceID)

        let canvas = LumiPreviewFacade.PreviewSurfaceCanvas(
            surfaceID: nil,
            isInteractive: false,
            cursorShape: .arrow
        )

        canvas.configure(view)

        XCTAssertNil(view.currentSurfaceID)
        XCTAssertNil(view.layer?.contents)
        XCTAssertEqual(view.debugContentLayerFrame, .zero)
        XCTAssertFalse(view.isInteractive)
        XCTAssertEqual(view.cursorShape, .arrow)
    }
}
