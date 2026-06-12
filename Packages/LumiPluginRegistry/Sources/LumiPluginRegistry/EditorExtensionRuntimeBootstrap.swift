import EditorGoPlugin
import EditorJSPlugin
import LumiCoreKit

@MainActor
public enum EditorExtensionRuntimeBootstrap {
    public static func configureRuntime(_ context: PluginRuntimeContext) async {
        await EditorGoPlugin.shared.configureRuntime(context: context)
        await EditorJSPlugin.shared.configureRuntime(context: context)
    }
}
