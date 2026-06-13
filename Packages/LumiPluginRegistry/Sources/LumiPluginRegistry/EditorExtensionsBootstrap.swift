import EditorService
import LumiCoreKit

@MainActor
public enum EditorExtensionsBootstrap {
    public static func registerAll(
        into registry: EditorExtensionRegistry,
        enabledPluginIDs: Set<String>? = nil
    ) async {
        registry.uninstallAll()

        var records: [EditorInstalledPluginRecord] = []

        for pluginType in EditorExtensionPluginRegistry.plugins {
            let info = pluginType.extensionPluginInfo
            let policy = pluginType.extensionPluginPolicy

            if let enabledPluginIDs {
                let isAlwaysOn = policy == .alwaysOn
                guard isAlwaysOn || enabledPluginIDs.contains(info.id) else { continue }
            }

            await pluginType.registerEditorExtensionsErased(into: registry)
            records.append(
                EditorInstalledPluginRecord(
                    id: info.id,
                    displayName: info.displayName,
                    description: info.description,
                    order: info.order,
                    isConfigurable: policy.isConfigurable
                )
            )
        }

        registry.recordInstalledPlugins(records)
    }

    public static func configureRuntime(_ context: PluginRuntimeContext) async {
        for pluginType in EditorExtensionPluginRegistry.plugins {
            await pluginType.configureEditorRuntime(context)
        }
    }
}
