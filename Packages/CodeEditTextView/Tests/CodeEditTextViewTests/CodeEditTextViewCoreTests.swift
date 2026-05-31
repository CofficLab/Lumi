import AppKit
import XCTest
@testable import CodeEditTextView

final class CodeEditTextViewCoreTests: XCTestCase {
    func testNSRangeIsEmptyReflectsLength() {
        XCTAssertTrue(NSRange(location: 4, length: 0).isEmpty)
        XCTAssertFalse(NSRange(location: 4, length: 1).isEmpty)
    }

    func testNSRangeTranslateMovesLocationOnly() {
        let range = NSRange(location: 10, length: 3)

        let translated = range.translate(location: -4)

        XCTAssertEqual(translated.location, 6)
        XCTAssertEqual(translated.length, 3)
    }

    func testEmphasisStyleEqualityIncludesAssociatedValues() {
        XCTAssertEqual(EmphasisStyle.standard, .standard)
        XCTAssertEqual(EmphasisStyle.underline(color: .systemBlue), .underline(color: .systemBlue))
        XCTAssertNotEqual(EmphasisStyle.underline(color: .systemBlue), .underline(color: .systemRed))
        XCTAssertEqual(EmphasisStyle.outline(color: .systemBlue, fill: true), .outline(color: .systemBlue, fill: true))
        XCTAssertNotEqual(EmphasisStyle.outline(color: .systemBlue, fill: true), .outline(color: .systemBlue, fill: false))
    }

    func testEmphasisStyleShapeRadiusMatchesStyle() {
        XCTAssertEqual(EmphasisStyle.standard.shapeRadius, 4)
        XCTAssertEqual(EmphasisStyle.underline(color: .systemBlue).shapeRadius, 0)
        XCTAssertEqual(EmphasisStyle.outline(color: .systemBlue).shapeRadius, 2.5)
    }

    func testSmoothPathSkipsConsecutiveDuplicatePoints() {
        let path = NSBezierPath.smoothPath(
            [
                NSPoint(x: 4, y: 4),
                NSPoint(x: 4, y: 4),
                NSPoint(x: 20, y: 4),
                NSPoint(x: 20, y: 12),
                NSPoint(x: 4, y: 4)
            ],
            radius: 3
        )

        XCTAssertGreaterThan(path.elementCount, 0)

        var points = [NSPoint](repeating: .zero, count: 3)
        for index in 0..<path.elementCount {
            _ = path.element(at: index, associatedPoints: &points)
            XCTAssertTrue(points.allSatisfy { $0.x.isFinite && $0.y.isFinite })
        }
    }
}
