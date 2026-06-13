import EditorService
import LumiCoreKit

public actor EditorScalaPlugin: SuperPlugin {
    public nonisolated static let policy: PluginPolicy = .optIn
    public static let shared = EditorScalaPlugin()
    public static let id = "scalaHighlight"
    public static let displayName = "Scala Highlight"
    public static let description = "Syntax highlighting and language detection for Scala."
    public static let iconName = "chevron.left.forwardslash.chevron.right"
    public static let order = 200
    public static var category: PluginCategory { .editor }
    public nonisolated var providesEditorExtensions: Bool { true }

    @MainActor
    public func registerEditorExtensions(into registry: any EditorExtensionRegistryProtocol) {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerLanguage(EditorScalaPluginDescriptor.descriptor)
        registry.registerGrammarProvider(EditorScalaPluginGrammarProvider())
    }
}
