import Foundation
import Testing

@testable import KernelLumi

/// `EditorDocumentSelector` 匹配契约测试（见重构方案 §9.4 / §21.1）。
@Suite("Editor Document Selector")
struct EditorDocumentSelectorTests {
    private func makeDocument(
        uri: String = "file:///tmp/Main.swift",
        languageID: String = "swift"
    ) -> EditorDocumentSummary {
        EditorDocumentSummary(
            id: .makeUnique(),
            uri: URL(string: uri)!,
            languageID: languageID,
            revision: 1,
            isDirty: false,
            isReadOnly: false,
            largeFileMode: .normal
        )
    }

    // MARK: - filter 组合（AND）

    @Test("空选择器匹配任意文档")
    func anySelectorMatchesEverything() {
        #expect(EditorDocumentSelector.any.matches(makeDocument()))
        #expect(EditorDocumentSelector.any.matches(makeDocument(uri: "mem://buffer", languageID: "json")))
    }

    @Test("language ID 过滤")
    func languageFilter() {
        let selector = EditorDocumentSelector(languageID: "swift")
        #expect(selector.matches(makeDocument()))
        #expect(selector.matches(makeDocument(languageID: "go")) == false)
    }

    @Test("scheme 过滤")
    func schemeFilter() {
        let selector = EditorDocumentSelector(scheme: "file")
        #expect(selector.matches(makeDocument()))
        #expect(selector.matches(makeDocument(uri: "mem://buffer")) == false)
    }

    @Test("扩展名过滤（大小写不敏感）")
    func extensionFilter() {
        let selector = EditorDocumentSelector(fileExtension: "swift")
        #expect(selector.matches(makeDocument(uri: "file:///tmp/a.swift")))
        #expect(selector.matches(makeDocument(uri: "file:///tmp/a.SWIFT")))
        #expect(selector.matches(makeDocument(uri: "file:///tmp/a.txt")) == false)
        #expect(selector.matches(makeDocument(uri: "file:///tmp/noext")) == false)
    }

    @Test("要求本地文件时拒绝非 file URI")
    func localFileFilter() {
        let selector = EditorDocumentSelector(requiresLocalFile: true)
        #expect(selector.matches(makeDocument()))
        #expect(selector.matches(makeDocument(uri: "mem://buffer")) == false)
    }

    @Test("多条件 AND 组合")
    func combinedFilters() {
        let selector = EditorDocumentSelector(languageID: "swift", fileExtension: "swift")
        let swiftFile = makeDocument()
        let wrongLanguage = makeDocument(languageID: "plaintext")
        #expect(selector.matches(swiftFile))
        #expect(selector.matches(wrongLanguage) == false)
    }

    // MARK: - glob

    @Test("文件名 glob 匹配")
    func globFilter() {
        let selector = EditorDocumentSelector(filenameGlob: "Package*.swift")
        #expect(selector.matches(makeDocument(uri: "file:///tmp/Package.swift")))
        #expect(selector.matches(makeDocument(uri: "file:///tmp/Package@Swift-6.0.swift")))
        #expect(selector.matches(makeDocument(uri: "file:///tmp/Main.swift")) == false)
    }

    @Test("glob 模式引擎行为")
    func globEngine() {
        func matches(_ pattern: String, _ name: String) -> Bool {
            EditorDocumentSelector.globPattern(pattern, matches: name)
        }
        #expect(matches("*.swift", "Main.swift"))
        #expect(matches("*.swift", ".swift"))
        #expect(matches("*.swift", "Main.txt") == false)
        #expect(matches("Package@Swift-*", "Package@Swift-6.0"))
        #expect(matches("Package@Swift-*", "Package.swift") == false)
        #expect(matches("Main.swift", "Main.swift"))
        #expect(matches("*", "anything"))
        #expect(matches("a*b*c", "aXbYc"))
        #expect(matches("a*b*c", "aXcYb") == false)
        #expect(matches("abc", "abcd") == false)
        #expect(matches("a**c", "abc"))
    }
}
