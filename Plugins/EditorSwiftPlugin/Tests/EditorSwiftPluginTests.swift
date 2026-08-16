@testable import EditorSwiftPlugin
import Foundation
import KernelLumi
import Testing

@MainActor @Test func editorSwiftPluginMetadata() {
    let plugin = EditorSwiftPlugin()

    #expect(plugin.id == "EditorSwift")
    #expect(plugin.name == "Swift 编辑器")
    #expect(plugin.order == 4)
    #expect(plugin.policy == .alwaysOn)
    #expect(plugin.category == .development)
    #expect(plugin.stage == .beta)
}

@MainActor @Test func editorSwiftPluginContributesContributionBundle() async throws {
    let bundle = try await EditorSwiftPlugin().editorContributionBundle(kernel: KernelLumi())
    let contribution = try #require(bundle?.languages.first)

    #expect(bundle?.pluginID == "EditorSwift")
    #expect(contribution.language == EditorSwiftPluginDescriptor.swift)
    #expect(contribution.grammar?.grammarId == "swift")
}

@MainActor @Test func swiftLanguageDescriptor() {
    let descriptor = EditorSwiftPluginDescriptor.swift

    #expect(descriptor.languageId == "swift")
    #expect(descriptor.displayName == "Swift")
    #expect(descriptor.fileExtensions == ["swift"])
    #expect(descriptor.shebangAliases == ["swift"])
    #expect(descriptor.lineComment == "//")
    #expect(descriptor.rangeComment?.0 == "/*")
    #expect(descriptor.rangeComment?.1 == "*/")
    #expect(descriptor.highlightLanguageId == "swift")
    #expect(descriptor.lspLanguageId == "swift")
}

@MainActor @Test func swiftGrammarProviderExposesBundledQueries() {
    let provider = EditorSwiftGrammarProvider()

    #expect(provider.grammarId == "swift")
    #expect(provider.treeSitterLanguage() != nil)
    #expect(provider.highlightQueryURLs().contains { $0.lastPathComponent == "highlights.scm" })
    #expect(provider.localsQueryURL()?.lastPathComponent == "locals.scm")
}

// MARK: - 语言功能 Provider（契约 V2 §10）

@MainActor @Test func bundleContainsLanguageFeatureProviders() async throws {
    let bundle = try await EditorSwiftPlugin().editorContributionBundle(kernel: KernelLumi())
    let providerIDs = bundle?.providers.map(\.id) ?? []

    #expect(providerIDs.contains("builtin.swift.primitive-types"))
    #expect(providerIDs.contains("builtin.swift.keyword-hover"))
    #expect(providerIDs.contains("builtin.swift.selection-actions"))
}

@MainActor @Test func primitiveTypeCompletionFiltersByTypeContextAndPrefix() async {
    let provider = SwiftPrimitiveTypeCompletionProvider()

    let typeRequest = EditorCompletionRequest(
        context: EditorFeatureRequestContext(uri: nil, languageID: "swift"),
        position: EditorPosition(line: 0, character: 8),
        prefix: "In",
        isTypeContext: true
    )
    let matched = await provider.completions(for: typeRequest)
    #expect(matched.map(\.label) == ["Int", "Int8", "Int16", "Int32", "Int64"])

    let valueRequest = EditorCompletionRequest(
        context: EditorFeatureRequestContext(uri: nil, languageID: "swift"),
        position: EditorPosition(line: 0, character: 8),
        prefix: "In",
        isTypeContext: false
    )
    #expect(await provider.completions(for: valueRequest).isEmpty)

    let otherLanguage = EditorCompletionRequest(
        context: EditorFeatureRequestContext(uri: nil, languageID: "python"),
        position: EditorPosition(line: 0, character: 8),
        prefix: "In",
        isTypeContext: true
    )
    #expect(await provider.completions(for: otherLanguage).isEmpty)
}

@MainActor @Test func keywordHoverReturnsDocsOnlyForKnownKeywords() async {
    let provider = SwiftKeywordHoverProvider()

    let request = EditorHoverRequest(
        context: EditorFeatureRequestContext(uri: nil, languageID: "swift"),
        position: EditorPosition(line: 0, character: 2),
        symbol: "actor"
    )
    let sections = await provider.hover(for: request)
    #expect(sections.count == 1)
    #expect(sections.first?.markdown.contains("actor") == true)

    let unknown = EditorHoverRequest(
        context: EditorFeatureRequestContext(uri: nil, languageID: "swift"),
        position: EditorPosition(line: 0, character: 2),
        symbol: "foobar"
    )
    #expect(await provider.hover(for: unknown).isEmpty)
}

@MainActor @Test func selectionCodeActionProducesURITextEdits() async {
    let provider = SwiftSelectionCodeActionProvider()
    let uri = URL(fileURLWithPath: "/tmp/Test.swift")
    let selection = EditorRange(
        start: EditorPosition(line: 2, character: 4),
        end: EditorPosition(line: 2, character: 10)
    )

    let request = EditorCodeActionRequest(
        context: EditorFeatureRequestContext(uri: uri, languageID: "swift"),
        position: selection.start,
        range: selection,
        selectedText: "compute()"
    )
    let actions = await provider.codeActions(for: request)

    #expect(actions.count == 2)
    let printAction = actions.first { $0.id == "builtin.swift.wrap-print" }
    #expect(printAction?.textEdits.first?.uri == uri)
    #expect(printAction?.textEdits.first?.edits.first?.newText == "print(compute())")

    let debugAction = actions.first { $0.id == "builtin.swift.wrap-debug" }
    #expect(debugAction?.textEdits.first?.edits.first?.newText == "#if DEBUG\ncompute()\n#endif")

    // 无选区时不提供动作。
    let noSelection = EditorCodeActionRequest(
        context: EditorFeatureRequestContext(uri: uri, languageID: "swift"),
        position: EditorPosition(line: 2, character: 4),
        range: EditorRange(at: EditorPosition(line: 2, character: 4)),
        selectedText: nil
    )
    #expect(await provider.codeActions(for: noSelection).isEmpty)
}
