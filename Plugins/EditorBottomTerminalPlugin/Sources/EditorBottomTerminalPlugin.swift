import LumiCoreKit
import LumiUI
import SwiftUI

public enum EditorBottomTerminalPanelPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let category: LumiPluginCategory = .development
    public static let iconName = "terminal"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.editor-bottom-terminal",
        displayName: "Editor Bottom Terminal",
        description: "Terminal panel in the editor bottom area.",
        order: 100
    )

    @MainActor
    public static func panelBottomTabItems(context: LumiPluginContext) -> [LumiPanelBottomTabItem] {
        guard context.showsPanelChrome else { return [] }

        return [
            LumiPanelBottomTabItem(
                id: "editor-bottom-terminal",
                order: info.order,
                title: String(localized: "Terminal", bundle: .module),
                systemImage: "terminal"
            ) {
                EditorBottomTerminalPanelView()
            }
        ]
    }
}
