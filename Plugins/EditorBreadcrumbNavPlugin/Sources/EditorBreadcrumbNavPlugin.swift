import EditorService
import LumiCoreKit
import LumiUI
import SwiftUI

public enum EditorBreadcrumbHeaderPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let category: LumiPluginCategory = .development
    public static let iconName = "point.topleft.down.curvedto.point.bottomright.up"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.editor-breadcrumb-header",
        displayName: "Editor Breadcrumb",
        description: "File path breadcrumb navigation below editor tabs.",
        order: 70
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
                BreadcrumbNavHeaderView(service: service)
            }
        ]
    }
}
