import EditorService
import LumiCoreKit
import LumiUI
import SwiftUI

public enum EditorBreadcrumbHeaderPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .development
    public static let iconName = "point.topleft.down.curvedto.point.bottomright.up"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.editor-breadcrumb-header",
        displayName: LumiPluginLocalization.string("Editor Breadcrumb", bundle: .module),
        description: LumiPluginLocalization.string("File path breadcrumb navigation below editor tabs.", bundle: .module),
        order: 88
    )

    @MainActor
    public static func panelHeaderItems(context: LumiPluginContext) -> [LumiPanelHeaderItem] {
        guard context.showsPanelChrome,
              let service = context.resolve(LumiEditorServicing.self)?.editorService,
              let lumiCore = context.lumiCore
        else {
            return []
        }

        return [
            LumiPanelHeaderItem(id: info.id, order: info.order) {
                NavHeaderView(service: service, lumiCore: lumiCore)
            }
        ]
    }
}
