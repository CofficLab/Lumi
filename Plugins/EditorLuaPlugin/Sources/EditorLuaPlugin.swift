import EditorService
import LumiCoreKit

public enum EditorLuaPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .optIn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .development
    public static let iconName = "chevron.left.forwardslash.chevron.right"

    public static let info = LumiPluginInfo(
        id: "luaHighlight",
        displayName: LumiPluginLocalization.string("Lua Highlight", bundle: .module),
        description: LumiPluginLocalization.string("Syntax highlighting and language detection for Lua.", bundle: .module),
        order: 200
    )

    public static func registerEditorExtensions(into registry: AnyObject) async {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerLanguage(EditorLuaPluginDescriptor.descriptor)
        registry.registerGrammarProvider(EditorLuaPluginGrammarProvider())
    }
}
