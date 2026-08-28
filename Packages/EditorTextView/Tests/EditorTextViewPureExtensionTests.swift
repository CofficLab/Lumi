import XCTest
import AppKit
@testable import EditorTextView

final class EditorTextViewPureExtensionTests: XCTestCase {
    func testBoundingRect() {
        XCTAssertEqual([CGRect]().boundingRect(), .zero)

        let rects = [
            CGRect(x: 0, y: 0, width: 10, height: 10),
            CGRect(x: 20, y: 5, width: 10, height: 20),
        ]
        let bounding = rects.boundingRect()
        XCTAssertEqual(bounding.minX, 0)
        XCTAssertEqual(bounding.minY, 0)
        XCTAssertEqual(bounding.maxX, 30)
        XCTAssertEqual(bounding.maxY, 25)
    }

    func testApproximateEqual() {
        XCTAssertTrue(CGFloat(1.0).approxEqual(1.2, tolerance: 0.5))
        XCTAssertFalse(CGFloat(1.0).approxEqual(2.0, tolerance: 0.5))
        XCTAssertTrue(CGPoint(x: 0, y: 0).approxEqual(CGPoint(x: 0.1, y: 0.4)))
        XCTAssertFalse(CGPoint(x: 0, y: 0).approxEqual(CGPoint(x: 10, y: 10)))
        XCTAssertTrue(
            CGRect(x: 0, y: 0, width: 10, height: 10)
                .approxEqual(CGRect(x: 0.2, y: 0.2, width: 10.2, height: 10.3))
        )
        XCTAssertFalse(
            CGRect(x: 0, y: 0, width: 10, height: 10)
                .approxEqual(CGRect(x: 5, y: 5, width: 10, height: 10))
        )
    }

    func testGrayscale() {
        let white = NSColor.white.grayscale
        XCTAssertEqual(white.whiteComponent, 1, accuracy: 0.01)
        let black = NSColor.black.grayscale
        XCTAssertEqual(black.whiteComponent, 0, accuracy: 0.01)
    }

    func testNSColorHexInit() {
        let color = NSColor(hex: 0xFF0000)
        XCTAssertEqual(color.redComponent, 1, accuracy: 0.01)
        XCTAssertEqual(color.greenComponent, 0, accuracy: 0.01)
        XCTAssertEqual(color.blueComponent, 0, accuracy: 0.01)

        let semi = NSColor(hex: 0x0000FF, alpha: 0.5)
        XCTAssertEqual(semi.blueComponent, 1, accuracy: 0.01)
        XCTAssertEqual(semi.alphaComponent, 0.5, accuracy: 0.01)
    }

    func testPixelAligned() {
        let rect = NSRect(x: 0.3, y: 0.3, width: 10.4, height: 10.4).pixelAligned
        XCTAssertEqual(rect.origin.x, 0, accuracy: 0.001)
        XCTAssertEqual(rect.width.rounded(), rect.width, accuracy: 0.001)

        let point = NSPoint(x: 1.4, y: 2.6).pixelAligned
        XCTAssertEqual(point.x.rounded(), point.x, accuracy: 0.001)
        XCTAssertEqual(point.y.rounded(), point.y, accuracy: 0.001)
    }

    func testEmphasisDefaults() {
        let emphasis = Emphasis(range: NSRange(location: 1, length: 2))
        XCTAssertEqual(emphasis.range, NSRange(location: 1, length: 2))
        XCTAssertFalse(emphasis.flash)
        XCTAssertFalse(emphasis.inactive)
        XCTAssertFalse(emphasis.selectInDocument)
        XCTAssertEqual(emphasis.style, .standard)
        XCTAssertEqual(emphasis, Emphasis(range: NSRange(location: 1, length: 2)))
    }
}
