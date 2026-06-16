import LumiCoreKit
import SwiftUI

public enum FontConfigPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .disabled
    public static let category: LumiPluginCategory = .theme
    public static let iconName = "textformat"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.font-config",
        displayName: LumiPluginLocalization.string("Font Config", bundle: .module),
        description: LumiPluginLocalization.string("Quick font switching in status bar", bundle: .module),
        order: 78
    )

    @MainActor
    public static func statusBarItems(context: LumiPluginContext) -> [LumiStatusBarItem] {
        [
            LumiStatusBarItem(
                id: info.id,
                title: info.displayName,
                systemImage: iconName,
                placement: .trailing,
                statusBarView: {
                    FontStatusBarView()
                }
            )
        ]
    }

        @MainActor
    public static func aboutView(context: LumiPluginContext) -> AnyView? {
        pluginAboutView(
            icon: iconName,
            displayName: info.displayName,
            description: info.description,
            kind: .general
        )
    }

}
