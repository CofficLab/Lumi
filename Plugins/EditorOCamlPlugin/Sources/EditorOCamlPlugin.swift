import EditorService
import LumiCoreKit

public actor EditorOCamlPlugin: SuperPlugin {
    public nonisolated static let policy: PluginPolicy = .optIn
    public static let shared = EditorOCamlPlugin()
    public static let id = "ocamlHighlight"
    public static let displayName = "OCaml Highlight"
    public static let description = "Syntax highlighting and language detection for OCaml."
    public static let iconName = "chevron.left.forwardslash.chevron.right"
    public static let order = 200
    public static var category: PluginCategory { .editor }
    public nonisolated var providesEditorExtensions: Bool { true }

    @MainActor
    public func registerEditorExtensions(into registry: any EditorExtensionRegistryProtocol) {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerLanguage(EditorOCamlPluginDescriptor.descriptor)
        registry.registerGrammarProvider(EditorOCamlPluginGrammarProvider())
    }
}
