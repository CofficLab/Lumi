import EditorService
import LumiCoreKit

public enum EditorPerlPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .optIn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .development
    public static let iconName = "chevron.left.forwardslash.chevron.right"

    public static let info = LumiPluginInfo(
        id: "perlHighlight",
        displayName: LumiPluginLocalization.string("Perl Highlight", bundle: .module),
        description: LumiPluginLocalization.string("Syntax highlighting and language detection for Perl.", bundle: .module),
        order: 200
    )

    public static func registerEditorExtensions(into registry: AnyObject) async {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerLanguage(EditorPerlPluginDescriptor.descriptor)
        registry.registerGrammarProvider(EditorPerlPluginGrammarProvider())
    }
}
