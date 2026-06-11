import LumiCoreKit
import SwiftUI

public enum DisplayControlPlugin: LumiPlugin {
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.display-control",
        displayName: LumiPluginLocalization.string("Display Control", bundle: .module),
        description: LumiPluginLocalization.string(
            "Control brightness, volume, and contrast for external displays via DDC/CI.",
            bundle: .module
        ),
        order: 21
    )
    public static let category: LumiPluginCategory = .system
    public static let policy: LumiPluginPolicy = .optIn

    public static let iconName = "display"

    @MainActor
    public static func viewContainers(context: LumiPluginContext) -> [LumiViewContainerItem] {
        [
            LumiViewContainerItem(
                id: info.id,
                title: LumiPluginLocalization.string("Display Control", bundle: .module),
                systemImage: iconName
            ) {
                DisplayControlView()
            }
        ]
    }

    @MainActor
    public static func settingsDetailView(context: LumiPluginContext) -> AnyView? {
        AnyView(DisplayControlView())
    }

    @MainActor
    public static func menuBarPopupItems(context: LumiPluginContext) -> [LumiMenuBarPopupItem] {
        [
            LumiMenuBarPopupItem(id: "\(info.id).controls", order: info.order) {
                DisplayMenuBarPopupView()
            }
        ]
    }
}
