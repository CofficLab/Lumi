import LumiCoreKit
import SwiftUI

public enum TerminalPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .optOut
    public static let category: LumiPluginCategory = .development
    public static let iconName = "terminal"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.terminal",
        displayName: String(localized: "Terminal", bundle: .module),
        description: String(localized: "Native interactive terminal powered by SwiftTerm", bundle: .module),
        order: 90
    )

    @MainActor
    public static func viewContainers(context: LumiPluginContext) -> [LumiViewContainerItem] {
        [
            LumiViewContainerItem(
                id: info.id,
                title: info.displayName,
                systemImage: iconName
            ) {
                TerminalMainView()
            }
        ]
    }
}
