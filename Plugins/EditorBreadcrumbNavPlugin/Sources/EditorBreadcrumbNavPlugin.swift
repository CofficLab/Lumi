import EditorService
import LumiCoreKit
import LumiUI
import SwiftUI
import os

public enum EditorBreadcrumbHeaderPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .development
    public static let iconName = "chevron.compact.right"
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.editor-breadcrumb-header")

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.editor-breadcrumb-header",
        displayName: LumiPluginLocalization.string("Editor Breadcrumb Header", bundle: .module),
        description: LumiPluginLocalization.string("Breadcrumb navigation header for the editor panel.", bundle: .module),
        order: 80
    )

    @MainActor
    public static func panelHeaderItems(context: LumiPluginContext) -> [LumiPanelHeaderItem] {
        guard context.showsPanelChrome else {
            return []
        }
        guard let service = context.resolve(LumiEditorServicing.self)?.editorService else { return [] }
        guard let lumiCore = context.lumiCore else { return [] }

        return [
            LumiPanelHeaderItem(id: info.id) {
                NavHeaderView(service: service, lumiCore: lumiCore)
            }
        ]
    }
}
