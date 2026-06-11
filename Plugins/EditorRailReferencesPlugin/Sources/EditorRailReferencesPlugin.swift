import EditorBottomReferencesPlugin
import EditorService
import LumiCoreKit
import LumiUI
import SwiftUI

public enum EditorRailReferencesPanelPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .optOut
    public static let category: LumiPluginCategory = .development
    public static let iconName = "arrow.triangle.branch"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.editor-rail-references",
        displayName: String(localized: "Editor Rail References", bundle: .module),
        description: String(localized: "References tab in the editor rail.", bundle: .module),
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
                title: String(localized: "References", bundle: .module),
                systemImage: "arrow.triangle.branch"
            ) {
                BottomEditorReferencesWorkspacePanelView(service: service, showsHeader: false)
            }
        ]
    }
}
