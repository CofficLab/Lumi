import XCTest
@testable import EditorSource

@MainActor
final class StyledRangeContainerExportTests: XCTestCase {
    func testExportHighlightRangesReturnsOnlyNonEmptyCaptures() {
        let container = StyledRangeContainer(documentLength: 20, providers: [0])
        container.applyHighlightResult(
            provider: 0,
            highlights: [
                HighlightRange(range: NSRange(location: 2, length: 3), capture: .keyword),
                HighlightRange(
                    range: NSRange(location: 10, length: 4),
                    capture: .variable,
                    modifiers: [.declaration]
                ),
            ],
            rangeToHighlight: NSRange(location: 0, length: 20)
        )

        let exported = container.exportHighlightRanges(providerId: 0)
        XCTAssertEqual(exported.count, 2)
        XCTAssertEqual(exported[0].range, NSRange(location: 2, length: 3))
        XCTAssertEqual(exported[0].capture, .keyword)
        XCTAssertEqual(exported[1].range, NSRange(location: 10, length: 4))
        XCTAssertEqual(exported[1].capture, .variable)
        XCTAssertEqual(exported[1].modifiers, [.declaration])
    }

    func testExportHighlightRangesForUnknownProviderIsEmpty() {
        let container = StyledRangeContainer(documentLength: 10, providers: [0])
        XCTAssertTrue(container.exportHighlightRanges(providerId: 42).isEmpty)
    }

    func testExportHighlightRangesAfterStorageUpdateShiftsRanges() {
        let container = StyledRangeContainer(documentLength: 20, providers: [0])
        container.applyHighlightResult(
            provider: 0,
            highlights: [HighlightRange(range: NSRange(location: 5, length: 5), capture: .string)],
            rangeToHighlight: NSRange(location: 0, length: 20)
        )

        // Insert 3 characters at location 2, shifting the highlight right.
        container.storageUpdated(editedRange: NSRange(location: 2, length: 3), changeInLength: 3)

        let exported = container.exportHighlightRanges(providerId: 0)
        XCTAssertEqual(exported.count, 1)
        XCTAssertEqual(exported[0].range, NSRange(location: 8, length: 5))
    }
}

final class ResultThrowOrReturnTests: XCTestCase {
    private enum TestError: Error, Equatable {
        case boom
    }

    func testThrowOrReturnSuccess() throws {
        let result: Result<Int, TestError> = .success(3)
        XCTAssertEqual(try result.throwOrReturn(), 3)
    }

    func testThrowOrReturnFailureThrows() {
        let result: Result<Int, TestError> = .failure(.boom)
        XCTAssertThrowsError(try result.throwOrReturn()) { error in
            XCTAssertEqual(error as? TestError, .boom)
        }
    }

    func testIsSuccess() {
        XCTAssertTrue((Result<Int, TestError>.success(1)).isSuccess)
        XCTAssertFalse((Result<Int, TestError>.failure(.boom)).isSuccess)
    }
}
