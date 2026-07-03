import EditorService
import LumiCoreKit

public enum EditorScalaPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .optIn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .development
    public static let iconName = "chevron.left.forwardslash.chevron.right"

    public static let info = LumiPluginInfo(
        id: "scalaHighlight",
        displayName: LumiPluginLocalization.string("Scala Highlight", bundle: .module),
        description: LumiPluginLocalization.string("Syntax highlighting and language detection for Scala.", bundle: .module),
        order: 200
    )

    public static func registerEditorExtensions(into registry: AnyObject) async {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerLanguage(EditorScalaPluginDescriptor.descriptor)
        registry.registerGrammarProvider(EditorScalaPluginGrammarProvider())
    }
}
