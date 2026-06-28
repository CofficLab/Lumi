import EditorService
import LumiCoreKit

public actor EditorAgdaPlugin: SuperPlugin {
    public nonisolated static let policy: PluginPolicy = .optIn
    public static let shared = EditorAgdaPlugin()
    public static let id = "agdaHighlight"
    public static let displayName = LumiPluginLocalization.string("Agda Highlight", bundle: .module)
    public static let description = LumiPluginLocalization.string("Syntax highlighting and language detection for Agda.", bundle: .module)
    public static let iconName = "chevron.left.forwardslash.chevron.right"
    public static let order = 200
    public static var category: PluginCategory { .editor }
    public nonisolated var providesEditorExtensions: Bool { true }

    @MainActor
    public func registerEditorExtensions(into registry: any EditorExtensionRegistryProtocol) {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerLanguage(EditorAgdaPluginDescriptor.descriptor)
        registry.registerGrammarProvider(EditorAgdaPluginGrammarProvider())
    }
}
