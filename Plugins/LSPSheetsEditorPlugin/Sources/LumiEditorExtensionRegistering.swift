import EditorService
import LumiCoreKit

extension LSPSheetsEditorPlugin: LumiEditorExtensionRegistering {
    public static var extensionPluginInfo: LumiPluginInfo {
        LumiPluginInfo(
            id: id,
            displayName: displayName,
            description: description,
            order: order
        )
    }

    public static var extensionPluginPolicy: LumiPluginPolicy {
        policy.lumiPluginPolicy
    }

    @MainActor
    public static func registerEditorExtensionsErased(into registry: AnyObject) async {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        await shared.registerEditorExtensions(into: registry)
    }
}
