import EditorService
import LumiCoreKit

extension LSPServiceEditorPlugin: LumiEditorExtensionRegistering {
    public static var extensionPluginInfo: LumiPluginInfo {
        info
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
