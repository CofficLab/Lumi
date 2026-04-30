#if canImport(XCTest)
import XCTest
@testable import Lumi

final class EditorSnippetParserTests: XCTestCase {
    func testParseBuildsPlaceholderGroupsAndExitSelection() {
        let result = EditorSnippetParser.parse("func ${1:name}($2) { $1($0) }")

        XCTAssertEqual(result.text, "func name() { name() }")
        XCTAssertEqual(result.groups.count, 2)
        XCTAssertEqual(result.groups[0].index, 1)
        XCTAssertEqual(result.groups[0].ranges, [
            NSRange(location: 5, length: 4),
            NSRange(location: 14, length: 4),
        ])
        XCTAssertEqual(result.groups[1].index, 2)
        XCTAssertEqual(result.groups[1].ranges, [NSRange(location: 10, length: 0)])
        XCTAssertEqual(result.exitSelection, NSRange(location: 19, length: 0))
    }

    func testParseUsesImplicitExitAtEndWhenSnippetDoesNotDeclareZeroTabstop() {
        let result = EditorSnippetParser.parse("let ${1:value} = ${2:other}")

        XCTAssertEqual(result.text, "let value = other")
        XCTAssertEqual(result.exitSelection, NSRange(location: 17, length: 0))
    }

    func testParseHonorsEscapedDollarAndBraceCharacters() {
        let result = EditorSnippetParser.parse("\\$${1:name\\}}")

        XCTAssertEqual(result.text, "$name}")
        XCTAssertEqual(result.groups.first?.ranges, [NSRange(location: 1, length: 5)])
    }
}
#endif
