import EditorService
import LumiCoreKit
import LumiUI
import SwiftUI

public enum EditorBottomReferencesPanelPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .optOut
    public static let category: LumiPluginCategory = .development
    public static let iconName = "arrow.triangle.branch"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.editor-bottom-references",
        displayName: LumiPluginLocalization.string("Editor Bottom References", bundle: .module),
        description: LumiPluginLocalization.string("References panel in the editor bottom area.", bundle: .module),
        order: 1
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
                id: "editor-bottom-references",
                order: info.order,
                title: LumiPluginLocalization.string("References", bundle: .module),
                systemImage: "arrow.triangle.branch"
            ) {
                BottomEditorReferencesWorkspacePanelView(service: service, showsHeader: false)
            }
        ]
    }
}
