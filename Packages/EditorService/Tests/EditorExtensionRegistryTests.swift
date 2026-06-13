#if canImport(XCTest)
@preconcurrency import EditorSource
import EditorLanguageRuntime
import EditorTextView
import XCTest
@testable import EditorService

@MainActor
private final class MockHighlightProvider: HighlightProviding {
    func setUp(textView: TextView, codeLanguage: EditorLanguageContext) {}

    func applyEdit(
        textView: TextView,
        range: NSRange,
        delta: Int,
        completion: @escaping @MainActor (Result<IndexSet, Error>) -> Void
    ) {
        completion(.success(IndexSet()))
    }

    func queryHighlightsFor(
        textView: TextView,
        range: NSRange,
        completion: @escaping @MainActor (Result<[HighlightRange], Error>) -> Void
    ) {
        completion(.success([]))
    }
}

@MainActor
private final class MockHighlightContributor: SuperEditorHighlightProviderContributor {
    let id: String = "mock.highlight"
    let provider = MockHighlightProvider()
    private(set) var supportsCallCount = 0
    private(set) var provideCallCount = 0

    func supports(languageId: String) -> Bool {
        supportsCallCount += 1
        return languageId == "markdown"
    }

    func provideHighlightProviders(languageId: String) -> [any HighlightProviding] {
        provideCallCount += 1
        return [provider]
    }
}

@MainActor
final class EditorExtensionRegistryTests: XCTestCase {
    func testHighlightProvidersCachesResultsPerLanguage() {
        let registry = EditorExtensionRegistry()
        let contributor = MockHighlightContributor()

        registry.registerHighlightProviderContributor(contributor)

        let first = registry.highlightProviders(for: "markdown")
        let second = registry.highlightProviders(for: "markdown")

        XCTAssertEqual(first.count, 1)
        XCTAssertEqual(second.count, 1)
        XCTAssertTrue(first[0] === second[0])
        XCTAssertEqual(contributor.supportsCallCount, 1)
        XCTAssertEqual(contributor.provideCallCount, 1)
    }
}
#endif
