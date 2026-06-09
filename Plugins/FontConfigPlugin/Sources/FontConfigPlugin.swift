import LumiCoreKit
import SwiftUI

public enum FontConfigPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .disabled
    public static let category: LumiPluginCategory = .theme
    public static let iconName = "textformat"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.font-config",
        displayName: String(localized: "Font Config", bundle: .module),
        description: String(localized: "Quick font switching in status bar", bundle: .module),
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
}
