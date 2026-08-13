@testable import EditorSwiftPlugin
import KernelLumi
import Testing

@Test func editorSwiftPluginMetadata() {
    let plugin = EditorSwiftPlugin()

    #expect(plugin.id == "EditorSwift")
    #expect(plugin.name == "Swift Editor")
    #expect(plugin.order == 4)
        #expect(plugin.policy == .optIn)
    #expect(plugin.category == .development)
    #expect(plugin.stage == .beta)
}

@Test func editorSwiftPluginContributesKernelEditorPlugin() {
    let plugin = EditorSwiftPlugin()
    let kernel = KernelLumi()
    let editorPlugins = plugin.editorPlugins(kernel: kernel)

    #expect(editorPlugins.count == 1)
    #expect(editorPlugins[0].id == "EditorSwift.language")
    #expect(editorPlugins[0].name == "Swift Language Support")
    #expect(editorPlugins[0].order == 4)
}

@Test func swiftEditorPluginRegistersLanguageAndGrammar() {
    let registrar = RecordingEditorExtensionRegistrar()
    EditorSwiftEditorPlugin().registerExtensions(into: registrar)

    #expect(registrar.languages == [EditorSwiftPluginDescriptor.swift])
    #expect(registrar.grammarProviders.count == 1)
    #expect(registrar.grammarProviders[0].grammarId == "swift")
}

@Test func swiftLanguageDescriptor() {
    let descriptor = EditorSwiftPluginDescriptor.swift

    #expect(descriptor.languageId == "swift")
    #expect(descriptor.name == "Swift")
    #expect(descriptor.fileExtensions == ["swift"])
    #expect(descriptor.shebangAliases == ["swift"])
    #expect(descriptor.lineComment == "//")
    #expect(descriptor.rangeComment?.0 == "/*")
    #expect(descriptor.rangeComment?.1 == "*/")
    #expect(descriptor.highlightLanguageId == "swift")
    #expect(descriptor.lspLanguageId == "swift")
}

@Test func swiftGrammarProviderExposesBundledQueries() {
    let provider = EditorSwiftGrammarProvider()

    #expect(provider.grammarId == "swift")
    #expect(provider.treeSitterLanguage() != nil)
    #expect(provider.highlightQueryURLs().contains { $0.lastPathComponent == "highlights.scm" })
    #expect(provider.localsQueryURL()?.lastPathComponent == "locals.scm")
}

private final class RecordingEditorExtensionRegistrar: EditorExtensionRegistrar {
    var languages: [EditorLanguageDescriptor] = []
    var grammarProviders: [any LanguageGrammarProviding] = []
    var highlightContributors: [any EditorHighlightContributor] = []

    func registerLanguage(_ descriptor: EditorLanguageDescriptor) {
        languages.append(descriptor)
    }

    func registerGrammarProvider(_ provider: any LanguageGrammarProviding) {
        grammarProviders.append(provider)
    }

    func registerHighlightContributor(_ contributor: any EditorHighlightContributor) {
        highlightContributors.append(contributor)
    }
}
