import LumiCoreKit
import LumiUI
import SwiftUI

public enum EditorRailFileTreePanelPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let category: LumiPluginCategory = .development
    public static let iconName = "folder"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.editor-rail-file-tree",
        displayName: String(localized: "Editor Rail File Tree", bundle: .module),
        description: String(localized: "Explorer tab in the editor rail.", bundle: .module),
        order: 0
    )

    @MainActor
    public static func panelRailTabItems(context: LumiPluginContext) -> [LumiPanelRailTabItem] {
        guard context.showsRail,
              context.activeSectionID == LumiEditorPanelContainer.id
        else { return [] }

        return [
            LumiPanelRailTabItem(
                id: "explorer",
                order: info.order,
                title: String(localized: "Explorer", bundle: .module),
                systemImage: "folder"
            ) {
                EditorFileTreeView()
            }
        ]
    }
}
