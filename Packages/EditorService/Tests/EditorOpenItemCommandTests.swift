#if canImport(XCTest)
import LanguageServerProtocol
import XCTest
@testable import EditorService

final class EditorOpenItemCommandTests: XCTestCase {
    func testCallHierarchyItemCommandAcceptsUnescapedFileURL() {
        let item = EditorCallHierarchyItem(
            name: "run",
            kind: .function,
            uri: "file:///tmp/project/My File.swift",
            range: LSPRange(
                start: Position(line: 0, character: 0),
                end: Position(line: 0, character: 3)
            ),
            selectionRange: LSPRange(
                start: Position(line: 4, character: 6),
                end: Position(line: 4, character: 9)
            ),
            data: nil
        )

        let command = EditorOpenItemCommand.callHierarchyItem(item)

        guard case let .callHierarchyItem(url, target)? = command.kernelValue else {
            return XCTFail("Expected call hierarchy item command")
        }

        XCTAssertEqual(url.path, "/tmp/project/My File.swift")
        XCTAssertEqual(target.start.line, 5)
        XCTAssertEqual(target.start.column, 7)
        XCTAssertNil(target.end)
    }
}
#endif
