#if canImport(XCTest)
import XCTest
import LanguageServerProtocol
@testable import Lumi

@MainActor
final class DocumentSymbolProviderTests: XCTestCase {
    func testDocumentSymbolItemBuildsNestedActivePath() {
        let item = EditorDocumentSymbolItem(
            symbol: DocumentSymbol(
                name: "Container",
                detail: "class",
                kind: .class,
                deprecated: nil,
                range: .init(
                    start: .init(line: 0, character: 0),
                    end: .init(line: 20, character: 0)
                ),
                selectionRange: .init(
                    start: .init(line: 0, character: 6),
                    end: .init(line: 0, character: 15)
                ),
                children: [
                    DocumentSymbol(
                        name: "render",
                        detail: "method",
                        kind: .method,
                        deprecated: nil,
                        range: .init(
                            start: .init(line: 4, character: 0),
                            end: .init(line: 8, character: 0)
                        ),
                        selectionRange: .init(
                            start: .init(line: 4, character: 4),
                            end: .init(line: 4, character: 10)
                        ),
                        children: nil
                    )
                ]
            )
        )

        XCTAssertEqual(item.children.count, 1)
        XCTAssertEqual(item.children.first?.line, 5)
        XCTAssertEqual(item.activePath(for: 6), ["Container", "Container/render"])
    }

    func testOpenItemCommandControllerResolvesDocumentSymbolToCursorPosition() {
        let item = EditorDocumentSymbolItem(
            id: "Container/render",
            name: "render",
            detail: "method",
            kind: .method,
            range: .init(
                start: .init(line: 4, character: 0),
                end: .init(line: 8, character: 0)
            ),
            selectionRange: .init(
                start: .init(line: 4, character: 4),
                end: .init(line: 4, character: 10)
            ),
            children: []
        )

        let resolved = EditorOpenItemCommandController.resolve(.documentSymbol(item))

        XCTAssertEqual(resolved?.cursorPositions.first?.start.line, 5)
        XCTAssertEqual(resolved?.cursorPositions.first?.start.column, 5)
        XCTAssertNil(resolved?.navigationRequest)
    }
}
#endif
