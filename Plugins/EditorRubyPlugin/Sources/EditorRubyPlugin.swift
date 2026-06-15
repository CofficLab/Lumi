import EditorService
import LumiCoreKit

public actor EditorRubyPlugin: SuperPlugin {
    public nonisolated static let policy: PluginPolicy = .optIn
    public static let shared = EditorRubyPlugin()
    public static let id = "rubyHighlight"
    public static let displayName = "Ruby Highlight"
    public static let description = "Syntax highlighting and language detection for Ruby."
    public static let iconName = "chevron.left.forwardslash.chevron.right"
    public static let order = 200
    public static var category: PluginCategory { .editor }
    public nonisolated var providesEditorExtensions: Bool { true }

    @MainActor
    public func registerEditorExtensions(into registry: any EditorExtensionRegistryProtocol) {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerLanguage(EditorRubyPluginDescriptor.descriptor)
        registry.registerGrammarProvider(EditorRubyPluginGrammarProvider())
    }
}
