import EditorService
import LumiCoreKit

public actor EditorPerlPlugin: SuperPlugin {
    public nonisolated static let policy: PluginPolicy = .optIn
    public static let shared = EditorPerlPlugin()
    public static let id = "perlHighlight"
    public static let displayName = "Perl Highlight"
    public static let description = "Syntax highlighting and language detection for Perl."
    public static let iconName = "chevron.left.forwardslash.chevron.right"
    public static let order = 200
    public static var category: PluginCategory { .editor }
    public nonisolated var providesEditorExtensions: Bool { true }

    @MainActor
    public func registerEditorExtensions(into registry: any EditorExtensionRegistryProtocol) {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerLanguage(EditorPerlPluginDescriptor.descriptor)
        registry.registerGrammarProvider(EditorPerlPluginGrammarProvider())
    }
}
