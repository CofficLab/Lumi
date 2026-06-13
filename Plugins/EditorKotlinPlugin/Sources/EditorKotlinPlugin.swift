import EditorService
import LumiCoreKit

public actor EditorKotlinPlugin: SuperPlugin {
    public nonisolated static let policy: PluginPolicy = .optIn
    public static let shared = EditorKotlinPlugin()
    public static let id = "kotlinHighlight"
    public static let displayName = "Kotlin Highlight"
    public static let description = "Syntax highlighting and language detection for Kotlin."
    public static let iconName = "chevron.left.forwardslash.chevron.right"
    public static let order = 200
    public static var category: PluginCategory { .editor }
    public nonisolated var providesEditorExtensions: Bool { true }

    @MainActor
    public func registerEditorExtensions(into registry: any EditorExtensionRegistryProtocol) {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerLanguage(EditorKotlinPluginDescriptor.descriptor)
        registry.registerGrammarProvider(EditorKotlinPluginGrammarProvider())
    }
}
