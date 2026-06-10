import EditorBottomCallHierarchyPlugin
import EditorService
import LumiCoreKit
import LumiUI
import SwiftUI

public enum EditorRailCallHierarchyPanelPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .optOut
    public static let category: LumiPluginCategory = .development
    public static let iconName = "point.3.connected.trianglepath.dotted"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.editor-rail-call-hierarchy",
        displayName: "Editor Rail Call Hierarchy",
        description: "Call hierarchy tab in the editor rail.",
        order: 14
    )

    @MainActor
    public static func panelRailTabItems(context: LumiPluginContext) -> [LumiPanelRailTabItem] {
        guard context.showsPanelChrome,
              let service = context.resolve(LumiEditorServicing.self)?.editorService
        else {
            return []
        }

        return [
            LumiPanelRailTabItem(
                id: "call-hierarchy",
                order: info.order,
                title: String(localized: "Calls", bundle: .module),
                systemImage: "point.3.connected.trianglepath.dotted"
            ) {
                BottomEditorCallHierarchyPanelView(service: service, showsHeader: false)
            }
        ]
    }
}
