import EditorBottomProblemsPlugin
import EditorService
import LumiCoreKit
import SwiftUI

public enum EditorRailProblemsPanelPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .optOut
    public static let category: LumiPluginCategory = .development
    public static let iconName = "exclamationmark.bubble"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.editor-rail-problems",
        displayName: LumiPluginLocalization.string("Editor Rail Problems", bundle: .module),
        description: LumiPluginLocalization.string("Problems tab in the editor rail.", bundle: .module),
        order: 10
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
                id: "problems",
                order: info.order,
                title: LumiPluginLocalization.string("Problems", bundle: .module),
                systemImage: "exclamationmark.bubble"
            ) {
                BottomEditorProblemsPanelView(service: service, showsHeader: false)
            }
        ]
    }

    @MainActor
    public static func aboutView(context: LumiPluginContext) -> AnyView? {
        pluginAboutView(
            features: [
                .init(icon: "exclamationmark.bubble", title: "Editor Rail Problems", description: "Problems tab in the editor rail."),
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
