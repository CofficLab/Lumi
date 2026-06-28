import EditorService
import LumiCoreKit

public actor EditorElixirPlugin: SuperPlugin {
    public nonisolated static let policy: PluginPolicy = .optIn
    public static let shared = EditorElixirPlugin()
    public static let id = "elixirHighlight"
    public static let displayName = LumiPluginLocalization.string("Elixir Highlight", bundle: .module)
    public static let description = LumiPluginLocalization.string("Syntax highlighting and language detection for Elixir.", bundle: .module)
    public static let iconName = "chevron.left.forwardslash.chevron.right"
    public static let order = 200
    public static var category: PluginCategory { .editor }
    public nonisolated var providesEditorExtensions: Bool { true }

    @MainActor
    public func registerEditorExtensions(into registry: any EditorExtensionRegistryProtocol) {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerLanguage(EditorElixirPluginDescriptor.descriptor)
        registry.registerGrammarProvider(EditorElixirPluginGrammarProvider())
    }
}
