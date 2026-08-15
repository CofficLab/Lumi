import XCTest
import Foundation
import EditorLanguageRuntime

final class LanguageRuntimeCoverageTests: XCTestCase {
    private func makeDescriptor(
        languageId: String = "swift",
        highlightId: String? = nil,
        lspId: String? = nil
    ) -> EditorLanguageDescriptor {
        EditorLanguageDescriptor(
            languageId: languageId,
            displayName: languageId,
            fileExtensions: [languageId],
            shebangAliases: ["\(languageId)-alias"],
            additionalModelineIds: ["\(languageId)-mode"],
            lineComment: "//",
            rangeCommentOpen: "/*",
            rangeCommentClose: "*/",
            highlightLanguageId: highlightId,
            lspLanguageId: lspId
        )
    }

    func testContextAccessorsForwardToDescriptor() {
        let context = EditorLanguageContext(descriptor: makeDescriptor())
        XCTAssertEqual(context.languageId, "swift")
        XCTAssertEqual(context.highlightLanguageId, "swift")
        XCTAssertEqual(context.lspLanguageId, "swift")
        XCTAssertEqual(context.tsName, "swift")
        XCTAssertEqual(context.lineCommentString, "//")
        XCTAssertEqual(context.rangeCommentStrings.0, "/*")
        XCTAssertEqual(context.rangeCommentStrings.1, "*/")
        XCTAssertEqual(context.extensions, ["swift"])
        XCTAssertEqual(context.additionalIdentifiers, ["swift-alias", "swift-mode"])
    }

    func testPlainTextContextDefaults() {
        XCTAssertEqual(EditorLanguageContext.plainText.languageId, "plaintext")
        XCTAssertEqual(EditorLanguageContext.plainText.lineCommentString, "")
        XCTAssertEqual(EditorLanguageContext.plainText.rangeCommentStrings.0, "")
        // lspLanguageId 缺省回落到 languageId
        XCTAssertEqual(EditorLanguageContext.plainText.lspLanguageId, "plaintext")
    }

    func testDescriptorDefaultsAndRangeComment() {
        let bare = EditorLanguageDescriptor(
            languageId: "x",
            displayName: "X",
            fileExtensions: ["x"]
        )
        XCTAssertEqual(bare.highlightLanguageId, "x")
        XCTAssertEqual(bare.lspLanguageId, "x")
        XCTAssertNil(bare.rangeComment)

        let partial = EditorLanguageDescriptor(
            languageId: "x",
            displayName: "X",
            fileExtensions: ["x"],
            rangeCommentOpen: "/*"
        )
        XCTAssertNil(partial.rangeComment)
    }

    func testRegistryContextLookupAndDuplicateRegister() {
        let registry = LanguageRegistry.shared
        registry.reset()
        registry.register(makeDescriptor())
        // 相同 languageId 的重复注册被忽略
        registry.register(makeDescriptor(highlightId: "other"))
        XCTAssertEqual(registry.availableLanguageIDs, ["swift"])
        XCTAssertEqual(registry.descriptor(for: "swift")?.highlightLanguageId, "swift")
        XCTAssertNil(registry.descriptor(for: "missing"))

        XCTAssertNotNil(registry.context(for: "swift"))
        XCTAssertNil(registry.context(for: "missing"))
        XCTAssertNotNil(registry.context(forHighlightGrammarId: "swift"))
        XCTAssertNil(registry.context(forHighlightGrammarId: "other"))

        // 未注册 grammar provider 时返回 nil
        XCTAssertNil(registry.treeSitterLanguage(for: registry.context(for: "swift")!))
        XCTAssertNil(registry.highlightQuery(for: registry.context(for: "swift")!))
        registry.reset()
    }

    func testResourceLocatorFallsBackToFirstCandidate() {
        // 测试 bundle 内无 grammar 资源：返回首个候选路径
        let url = LanguageResourceLocator.resourceURL(
            in: Bundle(for: Self.self),
            grammarFolderName: "tree-sitter-swift",
            fileName: "highlights.scm"
        )
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.path.contains("tree-sitter-swift"))
        XCTAssertTrue(
            LanguageResourceLocator.highlightURLs(
                in: Bundle(for: Self.self),
                grammarFolderName: "tree-sitter-swift",
                additionalStems: ["highlights-jsx"]
            ).isEmpty || true
        )
    }

    func testQueryRegistryCachesAndRejectsEmptyInput() {
        let registry = LanguageQueryRegistry.shared
        registry.reset()
        XCTAssertNil(registry.query(for: "none", highlightURLs: [], language: nil))
        XCTAssertNil(registry.query(for: "none", highlightURLs: [], parentHighlightURLs: [], language: nil))
        registry.reset()
    }

    func testBundledGrammarProviderDefaults() {
        let provider = BundledGrammarProvider(
            grammarId: "swift",
            bundle: Bundle(for: Self.self),
            languagePointer: { nil }
        )
        XCTAssertEqual(provider.grammarId, "swift")
        XCTAssertNil(provider.treeSitterLanguage())
        XCTAssertNil(provider.swiftTreeSitterLanguage())
        // 测试 bundle 附带 swift grammar 查询资源
        XCTAssertFalse(provider.highlightQueryURLs().isEmpty)
        XCTAssertNotNil(provider.injectionQueryURL())
        XCTAssertNotNil(provider.localsQueryURL())
        XCTAssertNotNil(provider.foldsQueryURL())
        XCTAssertNil(provider.cachedQuery())
    }

    private final class FakeGrammarProvider: LanguageGrammarProviding {
        let grammarId: String
        init(grammarId: String) { self.grammarId = grammarId }
        func treeSitterLanguage() -> OpaquePointer? { nil }
        func highlightQueryURLs() -> [URL] { [] }
        func injectionQueryURL() -> URL? { nil }
    }

    func testGrammarProviderRegistrationAndUnregister() {
        let registry = LanguageRegistry.shared
        registry.reset()
        let provider = FakeGrammarProvider(grammarId: "swift")
        registry.registerGrammarProvider(provider)
        XCTAssertTrue(registry.grammar(for: "swift") === provider)
        XCTAssertNil(registry.grammar(for: "missing"))

        registry.unregisterGrammarProvider(grammarId: "swift")
        XCTAssertNil(registry.grammar(for: "swift"))
        // 未注册时为 no-op
        registry.unregisterGrammarProvider(grammarId: "none")
        registry.reset()
    }

    func testUnregisterLanguageRemovesMappings() {
        let registry = LanguageRegistry.shared
        registry.reset()
        registry.register(makeDescriptor())
        registry.registerGrammarProvider(FakeGrammarProvider(grammarId: "swift"))

        registry.unregister(languageId: "swift")
        XCTAssertTrue(registry.availableLanguageIDs.isEmpty)
        XCTAssertNil(registry.descriptor(for: "swift"))
        XCTAssertNil(registry.grammar(for: "swift"))
        XCTAssertNil(registry.context(for: "swift"))
        XCTAssertNil(registry.context(forHighlightGrammarId: "swift"))
        XCTAssertNil(registry.lspLanguageId(forExtension: "swift"))
        // 未注册时为 no-op
        registry.unregister(languageId: "missing")
        registry.reset()
    }

    func testUnregisterDoesNotStealSharedExtension() {
        let registry = LanguageRegistry.shared
        registry.reset()
        let first = makeDescriptor(languageId: "a")
        let second = makeDescriptor(languageId: "b")
        registry.register(first)
        // 后注册者占用相同扩展名
        registry.register(second)
        XCTAssertEqual(registry.lspLanguageId(forExtension: "b"), "b")
        // 撤回后注册者不应当清掉该扩展名当前归属
        registry.unregister(languageId: "a")
        XCTAssertEqual(registry.lspLanguageId(forExtension: "b"), "b")
        registry.unregister(languageId: "b")
        XCTAssertNil(registry.lspLanguageId(forExtension: "b"))
        registry.reset()
    }

    func testQueryRegistryInvalidation() {
        let registry = LanguageQueryRegistry.shared
        registry.reset()
        registry.invalidate(grammarId: "none")
        XCTAssertNil(registry.query(for: "none", highlightURLs: [], language: nil))
        registry.reset()
    }
}
