import EditorService
import Foundation
import KernelCore
import PluginCodeEditorLanguages
import Testing

@Suite(.serialized)
@MainActor
struct CodeEditorLanguagesTests {
    @Test("registers descriptors and compilable highlight grammars")
    func registersLanguages() throws {
        LanguageRegistry.shared.reset()
        let kernel = KernelCoreContainer()
        let editor = EditorService(editorExtensionRegistry: EditorExtensionRegistry())
        try kernel.registerProvider(EditorService.self, editor)
        let plugin = CodeEditorLanguagesSuperPlugin()

        try plugin.onBoot(kernel: kernel)

        for descriptor in CodeEditorLanguagesSuperPlugin.descriptors {
            let context = try #require(LanguageRegistry.shared.context(for: descriptor.languageId))
            #expect(
                LanguageRegistry.shared.treeSitterLanguage(for: context) != nil,
                "Missing Tree-sitter grammar for \(descriptor.languageId)"
            )
            #expect(
                LanguageRegistry.shared.highlightQuery(for: context) != nil,
                "Invalid highlight query for \(descriptor.languageId)"
            )
        }
    }

    @Test("detects the built-in language set")
    func detectsLanguages() throws {
        LanguageRegistry.shared.reset()
        let kernel = KernelCoreContainer()
        let editor = EditorService(editorExtensionRegistry: EditorExtensionRegistry())
        try kernel.registerProvider(EditorService.self, editor)
        let plugin = CodeEditorLanguagesSuperPlugin()
        try plugin.onBoot(kernel: kernel)

        let expectations: [(String, String)] = [
            ("App.swift", "swift"),
            ("index.js", "javascript"),
            ("component.tsx", "typescriptreact"),
            ("config.json", "json"),
            ("README.md", "markdown"),
            ("tool.py", "python"),
            ("build.sh", "shellscript"),
            ("workflow.yml", "yaml"),
        ]
        for (name, languageID) in expectations {
            let context = LanguageRegistry.shared.detectLanguage(url: URL(fileURLWithPath: "/tmp/\(name)"))
            #expect(context.languageId == languageID)
        }
    }
}
