import AppKit
import XCTest
@testable import EditorCodeEditTextView

final class EditorCodeEditTextViewCoreTests: XCTestCase {
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

    func testDragSelectionRangeBuildsCharacterRangeBetweenOffsets() {
        XCTAssertEqual(
            TextViewDragSelectionRange.betweenOffsets(12, 4),
            NSRange(location: 4, length: 8)
        )
    }

    func testLineEndingDetectsCarriageReturnLineFeedBeforeLineFeed() {
        XCTAssertEqual(LineEnding(line: "let value = 1\r\n"), .carriageReturnLineFeed)
        XCTAssertEqual(LineEnding(line: "let value = 1\n"), .lineFeed)
        XCTAssertEqual(LineEnding(line: "let value = 1\r"), .carriageReturn)
        XCTAssertNil(LineEnding(line: "let value = 1"))
    }

    func testDragSelectionRangeRejectsNegativeOffsets() {
        XCTAssertNil(TextViewDragSelectionRange.betweenOffsets(-1, 4))
        XCTAssertNil(TextViewDragSelectionRange.betweenOffsets(4, -1))
    }

    func testDragSelectionRangeEnclosesWordOrLineRanges() {
        let range = TextViewDragSelectionRange.enclosing(
            NSRange(location: 10, length: 4),
            NSRange(location: 2, length: 3)
        )

        XCTAssertEqual(range, NSRange(location: 2, length: 12))
    }

    func testDragSelectionRangeRejectsOverflowingRanges() {
        XCTAssertNil(
            TextViewDragSelectionRange.enclosing(
                NSRange(location: Int.max, length: 1),
                NSRange(location: 0, length: 1)
            )
        )
        XCTAssertNil(
            TextViewDragSelectionRange.enclosing(
                NSRange(location: 1, length: Int.max),
                NSRange(location: 0, length: 1)
            )
        )
    }

    func testTextLayoutRangeValidatorClampsOverflowingDocumentRanges() {
        XCTAssertEqual(
            TextLayoutRangeValidator.clampedRange(NSRange(location: 3, length: 20), upperBound: 10),
            NSRange(location: 3, length: 7)
        )
    }

    func testTextLayoutRangeValidatorRejectsInvalidRanges() {
        XCTAssertNil(TextLayoutRangeValidator.clampedRange(NSRange(location: -1, length: 2), upperBound: 10))
        XCTAssertNil(TextLayoutRangeValidator.clampedRange(NSRange(location: 2, length: -1), upperBound: 10))
        XCTAssertNil(TextLayoutRangeValidator.clampedRange(NSRange(location: Int.max, length: 1), upperBound: 10))
        XCTAssertNil(TextLayoutRangeValidator.clampedRange(NSRange(location: 10, length: 1), upperBound: 10))
    }

    func testTextLayoutRangeValidatorKeepsValidEmptyRangesWhenAllowed() {
        XCTAssertNil(TextLayoutRangeValidator.clampedRange(NSRange(location: 10, length: 0), upperBound: 10))
        XCTAssertEqual(
            TextLayoutRangeValidator.clampedRange(NSRange(location: 10, length: 0), upperBound: 10, allowEmpty: true),
            NSRange(location: 10, length: 0)
        )
        XCTAssertNil(
            TextLayoutRangeValidator.clampedRange(NSRange(location: 11, length: 0), upperBound: 10, allowEmpty: true)
        )
    }
}
