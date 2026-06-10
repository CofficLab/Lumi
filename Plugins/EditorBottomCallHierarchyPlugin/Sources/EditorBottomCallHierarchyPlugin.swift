import EditorService
import LumiCoreKit
import LumiUI
import SwiftUI

public enum EditorBottomCallHierarchyPanelPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .optOut
    public static let category: LumiPluginCategory = .development
    public static let iconName = "point.3.connected.trianglepath.dotted"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.editor-bottom-call-hierarchy",
        displayName: "Editor Bottom Call Hierarchy",
        description: "Call hierarchy panel in the editor bottom area.",
        order: 4
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
                id: "editor-bottom-call-hierarchy",
                order: info.order,
                title: String(localized: "Call Hierarchy", bundle: .module),
                systemImage: "point.3.connected.trianglepath.dotted"
            ) {
                BottomEditorCallHierarchyPanelView(service: service, showsHeader: false)
            }
        ]
    }
}
