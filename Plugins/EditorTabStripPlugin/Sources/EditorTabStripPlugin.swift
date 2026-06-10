import EditorService
import LumiCoreKit
import LumiUI
import SwiftUI

public enum EditorTabStripHeaderPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let category: LumiPluginCategory = .development
    public static let iconName = "rectangle.topthird.inset.filled"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.editor-tab-strip-header",
        displayName: "Editor Tab Strip",
        description: "Tab bar for the editor panel.",
        order: 88
    )

    @MainActor
    public static func panelHeaderItems(context: LumiPluginContext) -> [LumiPanelHeaderItem] {
        guard context.showsPanelChrome,
              let service = context.resolve(LumiEditorServicing.self)?.editorService
        else {
            return []
        }

        return [
            LumiPanelHeaderItem(id: info.id, order: info.order) {
                EditorTabHeaderView(service: service)
            }
        ]
    }
}
