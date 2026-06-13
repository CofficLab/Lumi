import EditorService
import LumiCoreKit

public actor EditorTOMLPlugin: SuperPlugin {
    public nonisolated static let policy: PluginPolicy = .optIn
    public static let shared = EditorTOMLPlugin()
    public static let id = "tomlHighlight"
    public static let displayName = "TOML Highlight"
    public static let description = "Syntax highlighting and language detection for TOML."
    public static let iconName = "chevron.left.forwardslash.chevron.right"
    public static let order = 200
    public static var category: PluginCategory { .editor }
    public nonisolated var providesEditorExtensions: Bool { true }

    @MainActor
    public func registerEditorExtensions(into registry: any EditorExtensionRegistryProtocol) {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerLanguage(EditorTOMLPluginDescriptor.descriptor)
        registry.registerGrammarProvider(EditorTOMLPluginGrammarProvider())
    }
}
