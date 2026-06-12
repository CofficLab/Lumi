import XCTest
@testable import LumiPreviewKit

final class IOSurfaceFrameTests: XCTestCase {

    func test_frame_roundTripCoding() throws {
        let original = LumiPreviewFacade.IOSurfaceFrame(
            surfaceID: 42,
            width: 320,
            height: 180,
            scale: 2,
            seq: 7
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LumiPreviewFacade.IOSurfaceFrame.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func test_frame_equalityRequiresAllFields() {
        let base = LumiPreviewFacade.IOSurfaceFrame(
            surfaceID: 1, width: 10, height: 10, scale: 1, seq: 1
        )
        XCTAssertNotEqual(base, .init(surfaceID: 2, width: 10, height: 10, scale: 1, seq: 1))
        XCTAssertNotEqual(base, .init(surfaceID: 1, width: 11, height: 10, scale: 1, seq: 1))
        XCTAssertNotEqual(base, .init(surfaceID: 1, width: 10, height: 10, scale: 1, seq: 2))
    }
}
