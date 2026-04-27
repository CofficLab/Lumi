#if canImport(XCTest)
import XCTest
@testable import Lumi

final class EditorFindReplaceTransactionBuilderTests: XCTestCase {
    func testReplaceCurrentBuildsTransactionForSelectedMatch() {
        let state = EditorFindReplaceState(
            findText: "foo",
            replaceText: "bar",
            selectedMatchIndex: 1
        )
        let matches = [
            EditorFindMatch(range: EditorRange(location: 0, length: 3), matchedText: "foo"),
            EditorFindMatch(range: EditorRange(location: 4, length: 3), matchedText: "foo")
        ]

        let transaction = EditorFindReplaceTransactionBuilder.replaceCurrent(
            state: state,
            matches: matches
        )

        XCTAssertEqual(transaction?.replacements.count, 1)
        XCTAssertEqual(transaction?.replacements.first?.range, EditorRange(location: 4, length: 3))
        XCTAssertEqual(transaction?.replacements.first?.text, "bar")
        XCTAssertEqual(transaction?.updatedSelections?.first?.range, EditorRange(location: 4, length: 3))
    }

    func testReplaceAllPreservesCaseWhenEnabled() {
        let state = EditorFindReplaceState(
            findText: "foo",
            replaceText: "bar",
            options: EditorFindReplaceOptions(preservesCase: true)
        )
        let matches = [
            EditorFindMatch(range: EditorRange(location: 0, length: 3), matchedText: "FOO"),
            EditorFindMatch(range: EditorRange(location: 4, length: 3), matchedText: "Foo"),
            EditorFindMatch(range: EditorRange(location: 8, length: 3), matchedText: "foo")
        ]

        let transaction = EditorFindReplaceTransactionBuilder.replaceAll(
            state: state,
            matches: matches
        )

        XCTAssertEqual(transaction?.replacements.map(\.text), ["BAR", "Bar", "bar"])
    }
}
#endif
