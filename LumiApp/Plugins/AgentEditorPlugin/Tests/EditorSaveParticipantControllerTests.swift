#if canImport(XCTest)
import XCTest
@testable import Lumi

final class EditorSaveParticipantControllerTests: XCTestCase {
    func testPrepareTrimsTrailingWhitespacePerLine() {
        let result = EditorSaveParticipantController.prepare(
            text: "let value = 1   \nreturn value\t\t"
        )

        XCTAssertEqual(result.text, "let value = 1\nreturn value\n")
        XCTAssertTrue(result.didTrimTrailingWhitespace)
        XCTAssertTrue(result.didInsertFinalNewline)
    }

    func testPrepareDoesNotAppendFinalNewlineForEmptyText() {
        let result = EditorSaveParticipantController.prepare(text: "")

        XCTAssertEqual(result.text, "")
        XCTAssertFalse(result.didTrimTrailingWhitespace)
        XCTAssertFalse(result.didInsertFinalNewline)
    }

    func testPrepareCanDisableIndividualParticipants() {
        let result = EditorSaveParticipantController.prepare(
            text: "alpha   ",
            options: .init(
                trimTrailingWhitespace: false,
                insertFinalNewline: false
            )
        )

        XCTAssertEqual(result.text, "alpha   ")
        XCTAssertFalse(result.changed)
    }

    func testPreparePreservesExistingFinalNewline() {
        let result = EditorSaveParticipantController.prepare(
            text: "alpha\nbeta\n"
        )

        XCTAssertEqual(result.text, "alpha\nbeta\n")
        XCTAssertFalse(result.didTrimTrailingWhitespace)
        XCTAssertFalse(result.didInsertFinalNewline)
    }

    func testPreparePreservesCRLFLineEndings() {
        let result = EditorSaveParticipantController.prepare(
            text: "alpha   \r\nbeta\t"
        )

        XCTAssertEqual(result.text, "alpha\r\nbeta\r\n")
        XCTAssertTrue(result.didTrimTrailingWhitespace)
        XCTAssertTrue(result.didInsertFinalNewline)
    }
}
#endif
