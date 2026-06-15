import EditorBottomCallHierarchyPlugin
import EditorService
import LumiCoreKit
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

    @MainActor
    public static func aboutView(context: LumiPluginContext) -> AnyView? {
        pluginAboutView(
            features: [
                .init(icon: "point.3.connected.trianglepath.dotted", title: "Editor Rail Call Hierarchy", description: "Call hierarchy tab in the editor rail."),
                .init(icon: "sidebar.left", title: "Side Rail", description: "Adds a panel to the editor side rail"),
                .init(icon: "doc.text", title: "File Context", description: "Shows information related to the active editor file")
            ],
            steps: [
                "Enable the plugin in plugin settings",
                "Open a file in the code editor",
                "Select the rail tab provided by this plugin"
            ],
            tips: [
                "Collapse the rail when you need more editor space",
                "Combine with other rail plugins for a richer workflow"
            ]
        )
    }

}
