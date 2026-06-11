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
        displayName: LumiPluginLocalization.string("Editor Rail Call Hierarchy", bundle: .module),
        description: LumiPluginLocalization.string("Call hierarchy tab in the editor rail.", bundle: .module),
        order: 14
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
                id: "call-hierarchy",
                order: info.order,
                title: LumiPluginLocalization.string("Calls", bundle: .module),
                systemImage: "point.3.connected.trianglepath.dotted"
            ) {
                BottomEditorCallHierarchyPanelView(service: service, showsHeader: false)
            }
        ]
    }
}
