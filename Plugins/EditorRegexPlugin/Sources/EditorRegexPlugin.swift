import EditorService
import LumiCoreKit

public actor EditorRegexPlugin: SuperPlugin {
    public nonisolated static let policy: PluginPolicy = .optIn
    public static let shared = EditorRegexPlugin()
    public static let id = "regexHighlight"
    public static let displayName = LumiPluginLocalization.string("Regex Highlight", bundle: .module)
    public static let description = LumiPluginLocalization.string("Syntax highlighting and language detection for Regex.", bundle: .module)
    public static let iconName = "chevron.left.forwardslash.chevron.right"
    public static let order = 200
    public static var category: PluginCategory { .editor }
    public nonisolated var providesEditorExtensions: Bool { true }

    @MainActor
    public func registerEditorExtensions(into registry: any EditorExtensionRegistryProtocol) {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerLanguage(EditorRegexPluginDescriptor.descriptor)
        registry.registerGrammarProvider(EditorRegexPluginGrammarProvider())
    }
}
