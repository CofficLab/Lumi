import GoEditorPlugin
import JSEditorPlugin
import LumiCoreKit

@MainActor
public enum EditorExtensionRuntimeBootstrap {
    public static func configureRuntime(_ context: PluginRuntimeContext) async {
        await GoEditorPlugin.shared.configureRuntime(context: context)
        await JSEditorPlugin.shared.configureRuntime(context: context)
    }
}
