@testable import EditorSwiftPlugin
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
