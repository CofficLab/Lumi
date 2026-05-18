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

    func test_makeFrame_preservesScaleAndSequence() throws {
        let frame = try XCTUnwrap(
            LumiInlinePreviewFacade.DemoSurfaceFactory.makeFrame(
                width: 8,
                height: 6,
                scale: 1.5,
                seq: 42
            )
        )

        XCTAssertEqual(frame.width, 8)
        XCTAssertEqual(frame.height, 6)
        XCTAssertEqual(frame.scale, 1.5)
        XCTAssertEqual(frame.seq, 42)
    }

    func test_makeFrame_paintsTopHalfRedAndBottomHalfGreen() throws {
        let frame = try XCTUnwrap(
            LumiInlinePreviewFacade.DemoSurfaceFactory.makeFrame(
                width: 4,
                height: 4,
                scale: 1,
                seq: 1
            )
        )
        let surface = try XCTUnwrap(IOSurfaceLookup(IOSurfaceID(frame.surfaceID)))

        var seed: UInt32 = 0
        XCTAssertEqual(IOSurfaceLock(surface, [], &seed), KERN_SUCCESS)
        defer { _ = IOSurfaceUnlock(surface, [], &seed) }

        let bytesPerRow = Int(IOSurfaceGetBytesPerRowOfPlane(surface, 0))
        let baseAddress = try XCTUnwrap(IOSurfaceGetBaseAddressOfPlane(surface, 0))
        let buffer = baseAddress.bindMemory(to: UInt8.self, capacity: bytesPerRow * frame.height)

        XCTAssertEqual(pixel(atX: 0, y: 0, bytesPerRow: bytesPerRow, buffer: buffer), Pixel(b: 0, g: 0, r: 255, a: 255))
        XCTAssertEqual(pixel(atX: 0, y: 1, bytesPerRow: bytesPerRow, buffer: buffer), Pixel(b: 0, g: 0, r: 255, a: 255))
        XCTAssertEqual(pixel(atX: 0, y: 2, bytesPerRow: bytesPerRow, buffer: buffer), Pixel(b: 0, g: 255, r: 0, a: 255))
        XCTAssertEqual(pixel(atX: 0, y: 3, bytesPerRow: bytesPerRow, buffer: buffer), Pixel(b: 0, g: 255, r: 0, a: 255))
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

    func test_makeFrame_rejectsNegativeDimensions() {
        XCTAssertNil(
            LumiInlinePreviewFacade.DemoSurfaceFactory.makeFrame(
                width: -1, height: 10, scale: 1, seq: 1
            )
        )
        XCTAssertNil(
            LumiInlinePreviewFacade.DemoSurfaceFactory.makeFrame(
                width: 10, height: -1, scale: 1, seq: 1
            )
        )
    }

    private struct Pixel: Equatable {
        let b: UInt8
        let g: UInt8
        let r: UInt8
        let a: UInt8
    }

    private func pixel(
        atX x: Int,
        y: Int,
        bytesPerRow: Int,
        buffer: UnsafeMutablePointer<UInt8>
    ) -> Pixel {
        let offset = y * bytesPerRow + x * 4
        return Pixel(
            b: buffer[offset],
            g: buffer[offset + 1],
            r: buffer[offset + 2],
            a: buffer[offset + 3]
        )
    }
}
