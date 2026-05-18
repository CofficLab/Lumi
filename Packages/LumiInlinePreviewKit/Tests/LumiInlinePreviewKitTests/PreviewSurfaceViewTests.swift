import AppKit
import XCTest
@testable import LumiInlinePreviewKit

@MainActor
final class PreviewSurfaceViewTests: XCTestCase {

    func test_attach_setsCurrentSurfaceID_andLayerContents() throws {
        let frame = try XCTUnwrap(
            LumiInlinePreviewFacade.DemoSurfaceFactory.makeFrame(
                width: 32, height: 32, scale: 1, seq: 1
            )
        )
        let view = LumiInlinePreviewFacade.PreviewSurfaceView(frame: NSRect(x: 0, y: 0, width: 32, height: 32))
        XCTAssertNil(view.currentSurfaceID)

        view.attach(surfaceID: frame.surfaceID)

        XCTAssertEqual(view.currentSurfaceID, frame.surfaceID)
        XCTAssertNotNil(view.layer?.contents)
        XCTAssertTrue(view.subviews.isEmpty)
    }

    func test_detach_clearsContents() throws {
        let frame = try XCTUnwrap(
            LumiInlinePreviewFacade.DemoSurfaceFactory.makeFrame(
                width: 32, height: 32, scale: 1, seq: 1
            )
        )
        let view = LumiInlinePreviewFacade.PreviewSurfaceView()
        view.attach(surfaceID: frame.surfaceID)

        view.detach()

        XCTAssertNil(view.currentSurfaceID)
        XCTAssertNil(view.layer?.contents)
    }

    func test_attach_invalidSurfaceID_doesNotMutateState() {
        let view = LumiInlinePreviewFacade.PreviewSurfaceView()
        view.attach(surfaceID: 0xFFFF_FFFF)
        XCTAssertNil(view.currentSurfaceID)
    }

    func test_setCursorShape_updatesCurrentShape() {
        let view = LumiInlinePreviewFacade.PreviewSurfaceView()
        XCTAssertEqual(view.cursorShape, .arrow)

        view.setCursorShape(.pointingHand)

        XCTAssertEqual(view.cursorShape, .pointingHand)
    }
}
