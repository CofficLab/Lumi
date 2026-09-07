import Foundation
import XCTest
@testable import BookletMakerPlugin

final class BookletStageTests: XCTestCase {

    func testStageOrderIsFixed() {
        XCTAssertEqual(BookletStage.allCases, [
            .printLayout,
            .paperSelection,
            .cuttingMarks,
            .bindingEffect,
            .review,
            .export,
        ])
        XCTAssertEqual(BookletStage.allCases.map(\.stepNumber), [1, 2, 3, 4, 5, 6])
    }

    func testStageComparisonMatchesOrder() {
        XCTAssertTrue(BookletStage.export.isAfter(.printLayout))
        XCTAssertTrue(BookletStage.review.isAfter(.bindingEffect))
        XCTAssertFalse(BookletStage.printLayout.isAfter(.export))
    }

    func testEveryStageHasTitleAndIcon() {
        for stage in BookletStage.allCases {
            XCTAssertFalse(stage.title.isEmpty)
            XCTAssertFalse(stage.systemImage.isEmpty)
            XCTAssertEqual(stage.id, stage.rawValue)
        }
    }
}
