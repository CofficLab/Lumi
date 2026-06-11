import EditorService
import LumiCoreKit
import LumiUI
import SwiftUI

public enum EditorBottomSearchPanelPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .optOut
    public static let category: LumiPluginCategory = .development
    public static let iconName = "magnifyingglass"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.editor-bottom-search",
        displayName: String(localized: "Editor Bottom Search", bundle: .module),
        description: String(localized: "Search panel in the editor bottom area.", bundle: .module),
        order: 2
    )

    @MainActor
    public static func panelBottomTabItems(context: LumiPluginContext) -> [LumiPanelBottomTabItem] {
        guard context.showsPanelChrome,
              let service = context.resolve(LumiEditorServicing.self)?.editorService
        else {
            return []
        }

        return [
            LumiPanelBottomTabItem(
                id: "editor-bottom-search",
                order: info.order,
                title: String(localized: "Search", bundle: .module),
                systemImage: "magnifyingglass"
            ) {
                BottomEditorWorkspaceSearchPanelView(service: service, showsToolbar: true)
            }
        ]
    }
}
