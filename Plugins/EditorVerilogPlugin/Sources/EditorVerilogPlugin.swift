import EditorService
import LumiCoreKit

public actor EditorVerilogPlugin: SuperPlugin {
    public nonisolated static let policy: PluginPolicy = .optIn
    public static let shared = EditorVerilogPlugin()
    public static let id = "verilogHighlight"
    public static let displayName = "Verilog Highlight"
    public static let description = "Syntax highlighting and language detection for Verilog."
    public static let iconName = "chevron.left.forwardslash.chevron.right"
    public static let order = 200
    public static var category: PluginCategory { .editor }
    public nonisolated var providesEditorExtensions: Bool { true }

    @MainActor
    public func registerEditorExtensions(into registry: any EditorExtensionRegistryProtocol) {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerLanguage(EditorVerilogPluginDescriptor.descriptor)
        registry.registerGrammarProvider(EditorVerilogPluginGrammarProvider())
    }
}
