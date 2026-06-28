import EditorService
import LumiCoreKit

public actor EditorPHPPlugin: SuperPlugin {
    public nonisolated static let policy: PluginPolicy = .optIn
    public static let shared = EditorPHPPlugin()
    public static let id = "phpHighlight"
    public static let displayName = LumiPluginLocalization.string("PHP Highlight", bundle: .module)
    public static let description = LumiPluginLocalization.string("Syntax highlighting and language detection for PHP.", bundle: .module)
    public static let iconName = "chevron.left.forwardslash.chevron.right"
    public static let order = 200
    public static var category: PluginCategory { .editor }
    public nonisolated var providesEditorExtensions: Bool { true }

    @MainActor
    public func registerEditorExtensions(into registry: any EditorExtensionRegistryProtocol) {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerLanguage(EditorPHPPluginDescriptor.descriptor)
        registry.registerGrammarProvider(EditorPHPPluginGrammarProvider())
    }
}
