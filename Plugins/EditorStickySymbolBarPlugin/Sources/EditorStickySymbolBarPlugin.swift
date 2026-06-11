import EditorService
import LumiCoreKit
import LumiUI
import SwiftUI

public enum EditorStickySymbolBarHeaderPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .disabled
    public static let category: LumiPluginCategory = .development
    public static let iconName = "point.topleft.down.curvedto.point.bottomright.up"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.editor-sticky-symbol-bar-header",
        displayName: String(localized: "Editor Sticky Symbol Bar", bundle: .module),
        description: String(localized: "Current symbol breadcrumb for the editor panel.", bundle: .module),
        order: 89
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
                EditorStickySymbolBarHeaderView(service: service)
            }
        ]
    }
}
