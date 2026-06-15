import EditorBottomReferencesPlugin
import EditorService
import LumiCoreKit
import SwiftUI

public enum EditorRailReferencesPanelPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .optOut
    public static let category: LumiPluginCategory = .development
    public static let iconName = "arrow.triangle.branch"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.editor-rail-references",
        displayName: LumiPluginLocalization.string("Editor Rail References", bundle: .module),
        description: LumiPluginLocalization.string("References tab in the editor rail.", bundle: .module),
        order: 11
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
                id: "references",
                order: info.order,
                title: LumiPluginLocalization.string("References", bundle: .module),
                systemImage: "arrow.triangle.branch"
            ) {
                BottomEditorReferencesWorkspacePanelView(service: service, showsHeader: false)
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
