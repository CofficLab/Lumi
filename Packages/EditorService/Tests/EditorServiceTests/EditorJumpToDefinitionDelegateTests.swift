#if canImport(XCTest)
import XCTest
@testable import EditorService

final class EditorJumpToDefinitionDelegateTests: XCTestCase {
    func testSubstringIfValidReturnsTextForValidRange() {
        let text = "let cafe = 1"
        let range = (text as NSString).range(of: "cafe")

        XCTAssertEqual(
            EditorJumpToDefinitionDelegate.substringIfValid(in: text, range: range),
            "cafe"
        )
    }

    func testSubstringIfValidRejectsStaleRanges() {
        let text = "let value = 1"

        XCTAssertNil(EditorJumpToDefinitionDelegate.substringIfValid(
            in: text,
            range: NSRange(location: -1, length: 3)
        ))
        XCTAssertNil(EditorJumpToDefinitionDelegate.substringIfValid(
            in: text,
            range: NSRange(location: (text as NSString).length + 1, length: 1)
        ))
        XCTAssertNil(EditorJumpToDefinitionDelegate.substringIfValid(
            in: text,
            range: NSRange(location: 4, length: (text as NSString).length)
        ))
    }
}
#endif
