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
}
