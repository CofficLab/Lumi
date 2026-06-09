import LumiCoreKit
import SwiftUI

public enum RegistryManagerPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .disabled
    public static let category: LumiPluginCategory = .system
    public static let iconName = "arrow.triangle.2.circlepath"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.registry-manager",
        displayName: String(localized: "Registry Manager", bundle: .module),
        description: String(localized: "Manage Lumi registries", bundle: .module),
        order: 80
    )

    @MainActor
    public static func viewContainers(context: LumiPluginContext) -> [LumiViewContainerItem] {
        [
            LumiViewContainerItem(
                id: info.id,
                title: info.displayName,
                systemImage: iconName
            ) {
                RegistryManagerView()
            }
        ]
    }
}
