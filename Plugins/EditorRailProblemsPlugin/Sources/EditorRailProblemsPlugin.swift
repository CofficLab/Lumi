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
            icon: iconName,
            displayName: info.displayName,
            description: info.description,
            kind: .editorRail
        )
    }

}
