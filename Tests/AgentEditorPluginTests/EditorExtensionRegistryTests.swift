#if canImport(XCTest)
import XCTest
import CodeEditSourceEditor
import CodeEditTextView
import CodeEditLanguages
@testable import Lumi

@MainActor
final class EditorExtensionRegistryTests: XCTestCase {
    func testHighlightProvidersFiltersByLanguageAndDeduplicatesProviderInstances() {
        let registry = EditorExtensionRegistry()
        let sharedProvider = TestHighlightProvider()
        let swiftOnly = TestHighlightContributor(
            id: "swift-only",
            supportedLanguageIDs: ["swift"],
            providers: [sharedProvider]
        )
        let duplicateSwift = TestHighlightContributor(
            id: "swift-duplicate",
            supportedLanguageIDs: ["swift"],
            providers: [sharedProvider]
        )
        let markdownOnly = TestHighlightContributor(
            id: "markdown-only",
            supportedLanguageIDs: ["markdown"],
            providers: [TestHighlightProvider()]
        )

        registry.registerHighlightProviderContributor(swiftOnly)
        registry.registerHighlightProviderContributor(duplicateSwift)
        registry.registerHighlightProviderContributor(markdownOnly)

        let swiftProviders = registry.highlightProviders(for: "swift")
        let markdownProviders = registry.highlightProviders(for: "markdown")

        XCTAssertEqual(swiftProviders.count, 1)
        XCTAssertTrue(swiftProviders.first === sharedProvider)
        XCTAssertEqual(markdownProviders.count, 1)
        XCTAssertFalse(markdownProviders.first === sharedProvider)
    }
}

@MainActor
private final class TestHighlightContributor: EditorHighlightProviderContributor {
    let id: String
    private let supportedLanguageIDs: Set<String>
    private let providers: [any HighlightProviding]

    init(id: String, supportedLanguageIDs: Set<String>, providers: [any HighlightProviding]) {
        self.id = id
        self.supportedLanguageIDs = supportedLanguageIDs
        self.providers = providers
    }

    func supports(languageId: String) -> Bool {
        supportedLanguageIDs.contains(languageId)
    }

    func provideHighlightProviders(languageId: String) -> [any HighlightProviding] {
        providers
    }
}

@MainActor
private final class TestHighlightProvider: HighlightProviding {
    func setUp(textView: TextView, codeLanguage: CodeLanguage) {}

    func willApplyEdit(textView: TextView, range: NSRange) {}

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
#endif
