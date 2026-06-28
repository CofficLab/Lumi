import EditorService
import LumiCoreKit

public actor EditorLuaPlugin: SuperPlugin {
    public nonisolated static let policy: PluginPolicy = .optIn
    public static let shared = EditorLuaPlugin()
    public static let id = "luaHighlight"
    public static let displayName = LumiPluginLocalization.string("Lua Highlight", bundle: .module)
    public static let description = LumiPluginLocalization.string("Syntax highlighting and language detection for Lua.", bundle: .module)
    public static let iconName = "chevron.left.forwardslash.chevron.right"
    public static let order = 200
    public static var category: PluginCategory { .editor }
    public nonisolated var providesEditorExtensions: Bool { true }

    @MainActor
    public func registerEditorExtensions(into registry: any EditorExtensionRegistryProtocol) {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerLanguage(EditorLuaPluginDescriptor.descriptor)
        registry.registerGrammarProvider(EditorLuaPluginGrammarProvider())
    }
}
