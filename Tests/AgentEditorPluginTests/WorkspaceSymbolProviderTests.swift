#if canImport(XCTest)
import XCTest
import LanguageServerProtocol
@testable import Lumi

@MainActor
final class WorkspaceSymbolProviderTests: XCTestCase {
    func testSearchSymbolsStopsOnPreflightError() async {
        let provider = WorkspaceSymbolProvider(
            preflightMessageProvider: { _, _ in "Workspace Symbols: Build context 不可用" },
            requestSymbols: { _ in
                XCTFail("requestSymbols should not run when preflight fails")
                return nil
            }
        )

        await provider.searchSymbols(query: "Editor")

        XCTAssertFalse(provider.isSearching)
        XCTAssertEqual(provider.searchError, "Workspace Symbols: Build context 不可用")
        XCTAssertTrue(provider.symbols.isEmpty)
    }

    func testSearchSymbolsMapsSymbolInformationResponse() async {
        let provider = WorkspaceSymbolProvider(
            preflightMessageProvider: { _, _ in nil },
            requestSymbols: { _ in
                .optionA([
                    SymbolInformation(
                        name: "EditorPlugin",
                        kind: .class,
                        tags: nil,
                        deprecated: nil,
                        location: .init(
                            uri: "file:///tmp/EditorPlugin.swift",
                            range: .init(
                                start: .init(line: 10, character: 4),
                                end: .init(line: 10, character: 16)
                            )
                        ),
                        containerName: "AgentEditorPlugin"
                    )
                ])
            }
        )

        await provider.searchSymbols(query: "Editor")
        try? await Task.sleep(for: .milliseconds(10))

        XCTAssertFalse(provider.isSearching)
        XCTAssertNil(provider.searchError)
        XCTAssertEqual(provider.symbols.count, 1)
        XCTAssertEqual(provider.symbols.first?.name, "EditorPlugin")
        XCTAssertEqual(provider.symbols.first?.containerName, "AgentEditorPlugin")
        XCTAssertEqual(provider.symbols.first?.kind, .class)
        XCTAssertEqual(provider.symbols.first?.location.uri, "file:///tmp/EditorPlugin.swift")
    }
}
#endif
