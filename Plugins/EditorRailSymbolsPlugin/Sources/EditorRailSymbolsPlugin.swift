import EditorBottomSymbolsPlugin
import EditorService
import LumiCoreKit
import LumiUI
import SwiftUI

public enum EditorRailSymbolsPanelPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .optOut
    public static let category: LumiPluginCategory = .development
    public static let iconName = "number"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.editor-rail-symbols",
        displayName: "Editor Rail Symbols",
        description: "Symbols tab in the editor rail.",
        order: 13
    )

    @MainActor
    public static func panelRailTabItems(context: LumiPluginContext) -> [LumiPanelRailTabItem] {
        guard context.showsRail,
              context.activeSectionID == LumiEditorPanelContainer.id,
              let service = context.resolve(LumiEditorServicing.self)?.editorService
        else {
            return []
        }

        return [
            LumiPanelRailTabItem(
                id: "symbols",
                order: info.order,
                title: String(localized: "Symbols", bundle: .module),
                systemImage: "number"
            ) {
                BottomEditorWorkspaceSymbolsPanelView(service: service, showsHeader: false)
            }
        ]
    }
}
