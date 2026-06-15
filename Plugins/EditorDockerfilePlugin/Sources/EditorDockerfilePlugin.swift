import EditorService
import LumiCoreKit

public actor EditorDockerfilePlugin: SuperPlugin {
    public nonisolated static let policy: PluginPolicy = .optIn
    public static let shared = EditorDockerfilePlugin()
    public static let id = "dockerfileHighlight"
    public static let displayName = "Dockerfile Highlight"
    public static let description = "Syntax highlighting and language detection for Dockerfile."
    public static let iconName = "chevron.left.forwardslash.chevron.right"
    public static let order = 200
    public static var category: PluginCategory { .editor }
    public nonisolated var providesEditorExtensions: Bool { true }

    @MainActor
    public func registerEditorExtensions(into registry: any EditorExtensionRegistryProtocol) {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerLanguage(EditorDockerfilePluginDescriptor.descriptor)
        registry.registerGrammarProvider(EditorDockerfilePluginGrammarProvider())
    }
}
