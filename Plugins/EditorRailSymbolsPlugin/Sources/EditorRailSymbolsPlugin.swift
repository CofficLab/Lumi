import EditorBottomSymbolsPlugin
import EditorService
import LumiCoreKit
import SwiftUI

public enum EditorRailSymbolsPanelPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .optOut
    public static let category: LumiPluginCategory = .development
    public static let iconName = "number"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.editor-rail-symbols",
        displayName: LumiPluginLocalization.string("Editor Rail Symbols", bundle: .module),
        description: LumiPluginLocalization.string("Symbols tab in the editor rail.", bundle: .module),
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
                title: LumiPluginLocalization.string("Symbols", bundle: .module),
                systemImage: "number"
            ) {
                BottomEditorWorkspaceSymbolsPanelView(service: service, showsHeader: false)
            }
        ]
    }

    @MainActor
    public static func aboutView(context: LumiPluginContext) -> AnyView? {
        pluginAboutView(
            features: [
                .init(icon: "number", title: "Editor Rail Symbols", description: "Symbols tab in the editor rail."),
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
