import EditorService
import LumiCoreKit
import LumiUI
import SwiftUI

public enum EditorBottomSymbolsPanelPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .optOut
    public static let category: LumiPluginCategory = .development
    public static let iconName = "list.bullet.rectangle"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.editor-bottom-symbols",
        displayName: String(localized: "Editor Bottom Symbols", bundle: .module),
        description: String(localized: "Symbols panel in the editor bottom area.", bundle: .module),
        order: 3
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
                id: "editor-bottom-symbols",
                order: info.order,
                title: String(localized: "Symbols", bundle: .module),
                systemImage: "list.bullet.rectangle"
            ) {
                BottomEditorWorkspaceSymbolsPanelView(service: service, showsHeader: false)
            }
        ]
    }
}
