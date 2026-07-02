import EditorService
import LumiCoreKit

extension EditorCSSPlugin: LumiEditorExtensionRegistering {
    public static var extensionPluginInfo: LumiPluginInfo {
        LumiPluginInfo(
            id: info.id,
            displayName: info.displayName,
            description: info.description,
            order: info.order
        )
    }

    public static var extensionPluginPolicy: LumiPluginPolicy {
        policy
    }

    @MainActor
    public static func registerEditorExtensionsErased(into registry: AnyObject) async {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        await Self.registerEditorExtensions(into: registry)
    }
}
