#if canImport(XCTest)
import XCTest
import LanguageServerProtocol
@testable import Lumi

@MainActor
final class LSPCoordinatorDocumentSymbolsTests: XCTestCase {
    func testRequestDocumentSymbolsStopsOnSoftPreflightError() async {
        let coordinator = LSPCoordinator(
            documentSymbolsPreflight: { _ in .fileNotInTarget("EditorPlugin.swift") },
            requestDocumentSymbolsOperation: { _ in
                XCTFail("document symbols request should not run when preflight fails")
                return []
            }
        )
        coordinator.fileURI = "file:///tmp/EditorPlugin.swift"

        let result = await coordinator.requestDocumentSymbols()

        XCTAssertTrue(result.isEmpty)
    }

    func testRequestDocumentSymbolsReturnsRequestedSymbols() async {
        let symbol = DocumentSymbol(
            name: "EditorPlugin",
            detail: "class",
            kind: .class,
            tags: nil,
            deprecated: nil,
            range: .init(
                start: .init(line: 3, character: 0),
                end: .init(line: 20, character: 1)
            ),
            selectionRange: .init(
                start: .init(line: 3, character: 6),
                end: .init(line: 3, character: 18)
            ),
            children: nil
        )
        let coordinator = LSPCoordinator(
            documentSymbolsPreflight: { _ in nil },
            requestDocumentSymbolsOperation: { _ in [symbol] }
        )
        coordinator.fileURI = "file:///tmp/EditorPlugin.swift"

        let result = await coordinator.requestDocumentSymbols()

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.name, "EditorPlugin")
        XCTAssertEqual(result.first?.kind, .class)
    }
}
#endif
