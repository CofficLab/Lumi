import EditorService
import LumiCoreKit

public actor EditorBashPlugin: SuperPlugin {
    public nonisolated static let policy: PluginPolicy = .optIn
    public static let shared = EditorBashPlugin()
    public static let id = "bashHighlight"
    public static let displayName = "Bash Highlight"
    public static let description = "Syntax highlighting and language detection for Bash."
    public static let iconName = "chevron.left.forwardslash.chevron.right"
    public static let order = 200
    public static var category: PluginCategory { .editor }
    public nonisolated var providesEditorExtensions: Bool { true }

    @MainActor
    public func registerEditorExtensions(into registry: any EditorExtensionRegistryProtocol) {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerLanguage(EditorBashPluginDescriptor.descriptor)
        registry.registerGrammarProvider(EditorBashPluginGrammarProvider())
    }
}
