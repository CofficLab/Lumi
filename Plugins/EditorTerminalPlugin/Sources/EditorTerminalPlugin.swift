import LumiCoreKit
import LumiUI
import SwiftUI
import os

public enum EditorTerminalPanelPlugin: LumiPlugin {
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.editor-terminal-panel")

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.editor-bottom-terminal",
        displayName: LumiPluginLocalization.string("Editor Terminal", bundle: .module),
        description: LumiPluginLocalization.string("Terminal panel in the editor bottom area.", bundle: .module),
        order: 100,
        category: .development,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "terminal",
    )

    @MainActor
    public static func panelBottomTabItems(context: LumiPluginContext) -> [LumiPanelBottomTabItem] {
        guard context.showsPanelChrome else { return [] }

        return [
            LumiPanelBottomTabItem(
                id: "editor-bottom-terminal",
                order: info.order,
                title: LumiPluginLocalization.string("Terminal", bundle: .module),
                systemImage: iconName
            ) {
                EditorBottomTerminalPanelView()
            }
        ]
    }
}
