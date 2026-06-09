import LumiCoreKit
import SwiftUI

public enum NettoPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .disabled
    public static let category: LumiPluginCategory = .general
    public static let iconName = "shield.lefthalf.filled"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.netto",
        displayName: String(localized: "Netto Firewall", bundle: .module),
        description: String(localized: "Manage network permissions for macOS applications.", bundle: .module),
        order: 99
    )

    @MainActor
    public static func viewContainers(context: LumiPluginContext) -> [LumiViewContainerItem] {
        [
            LumiViewContainerItem(
                id: info.id,
                title: info.displayName,
                systemImage: iconName
            ) {
                NettoDashboardView()
            }
        ]
    }
}
