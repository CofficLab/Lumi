#if canImport(XCTest)
@preconcurrency import EditorSource
import EditorLanguageRuntime
import EditorTextView
import XCTest
@testable import EditorService
import KernelLumi

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

/// 模拟高亮插件：其实体同时遵循内核标记协议与 `HighlightProviding`。
extension MockHighlightProvider: EditorHighlightProvider {}

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
private final class MockKernelHighlightContributor: EditorHighlightContributor {
    let id = "mock.kernel.highlight"

    func supports(languageId: String) -> Bool { languageId == "markdown" }

    /// 以内核可见的标记类型返回底层 `HighlightProviding` 实例。
    func highlightProviders(for languageId: String) -> [any EditorHighlightProvider] {
        [MockHighlightProvider()]
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

    /// 验证高亮插件仅面向内核（`EditorHighlightContributor`）注册时，
    /// EditorService 能正确桥接并使其高亮 provider 生效。
    func testRegisterHighlightContributorViaKernelBridge() {
        let registry = EditorExtensionRegistry()
        let contributor = MockKernelHighlightContributor()

        registry.registerHighlightContributor(contributor)

        let providers = registry.highlightProviders(for: "markdown")
        XCTAssertEqual(providers.count, 1)
        XCTAssertTrue(providers[0] is MockHighlightProvider)
    }
}
#endif
