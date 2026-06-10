import LumiCoreKit
import LumiUI
import SwiftUI

public enum EditorRailFileTreePanelPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let category: LumiPluginCategory = .development
    public static let iconName = "folder"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.editor-rail-file-tree",
        displayName: "Editor Rail File Tree",
        description: "Explorer tab in the editor rail.",
        order: 0
    )

    @MainActor
    public static func editorRailTabItems(context: LumiPluginContext) -> [LumiEditorRailTabItem] {
        guard context.showsPanelChrome else { return [] }

        return [
            LumiEditorRailTabItem(
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
