#if canImport(XCTest)
import LanguageServerProtocol
import XCTest
@testable import EditorService

final class EditorCallHierarchyItemTests: XCTestCase {
    func testFileBadgeAcceptsUnescapedFileURL() {
        let item = EditorCallHierarchyItem(
            name: "run",
            kind: .function,
            uri: "file:///tmp/project/My File.swift",
            range: LSPRange(
                start: Position(line: 0, character: 0),
                end: Position(line: 0, character: 3)
            ),
            selectionRange: LSPRange(
                start: Position(line: 0, character: 0),
                end: Position(line: 0, character: 3)
            ),
            data: nil
        )

        XCTAssertEqual(item.fileBadge, "My File.swift")
    }

    func testFileBadgeFallsBackForNonFileURI() {
        let item = EditorCallHierarchyItem(
            name: "run",
            kind: .function,
            uri: "https://example.com/My%20File.swift",
            range: LSPRange(
                start: Position(line: 0, character: 0),
                end: Position(line: 0, character: 3)
            ),
            selectionRange: LSPRange(
                start: Position(line: 0, character: 0),
                end: Position(line: 0, character: 3)
            ),
            data: nil
        )

        XCTAssertEqual(item.fileBadge, "Symbol")
    }
}
#endif
