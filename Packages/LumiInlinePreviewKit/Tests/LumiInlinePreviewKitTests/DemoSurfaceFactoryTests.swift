import IOSurface
import XCTest
@testable import LumiInlinePreviewKit

final class DemoSurfaceFactoryTests: XCTestCase {

    func test_makeFrame_returnsResolvableSurface() throws {
        let frame = try XCTUnwrap(
            LumiInlinePreviewFacade.DemoSurfaceFactory.makeFrame(
                width: 64,
                height: 32,
                scale: 1,
                seq: 1
            )
        )
        XCTAssertEqual(frame.width, 64)
        XCTAssertEqual(frame.height, 32)
        XCTAssertGreaterThan(frame.surfaceID, 0)

        let surface = IOSurfaceLookup(IOSurfaceID(frame.surfaceID))
        XCTAssertNotNil(surface, "Frame surface should be resolvable in the same process")

        if let surface {
            XCTAssertEqual(IOSurfaceGetWidth(surface), 64)
            XCTAssertEqual(IOSurfaceGetHeight(surface), 32)
        }
    }

    func test_makeFrame_rejectsZeroDimensions() {
        XCTAssertNil(
            LumiInlinePreviewFacade.DemoSurfaceFactory.makeFrame(
                width: 0, height: 10, scale: 1, seq: 1
            )
        )
        XCTAssertNil(
            LumiInlinePreviewFacade.DemoSurfaceFactory.makeFrame(
                width: 10, height: 0, scale: 1, seq: 1
            )
        )
    }
}
