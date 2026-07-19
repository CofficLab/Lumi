import EditorService
import LumiCoreKit
import LumiUI
import SwiftUI
import os

public enum EditorPreviewBottomPanelPlugin: LumiPlugin {
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.editor-preview-bottom-panel")

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.editor-bottom-preview",
        displayName: LumiPluginLocalization.string("Editor Preview", bundle: .module),
        description: LumiPluginLocalization.string("Preview panel in the editor bottom area.", bundle: .module),
        order: 84,
        category: .development,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "eye",
    )

    @MainActor
    public static func panelBottomTabItems(context: any LumiCoreAccessing) -> [LumiPanelBottomTabItem] {
        bootstrapFromLumiCoreIfNeeded(context: context)
        guard context.showsPanelChrome else { return [] }
        guard let lumiCore = context.lumiCore else { return [] }

        return [
            LumiPanelBottomTabItem(
                id: "editor-bottom-preview",
                order: info.order,
                title: LumiPluginLocalization.string("Preview", bundle: .module),
                systemImage: iconName
            ) {
                EditorPreviewDetailView(lumiCore: lumiCore)
            }
        ]
    }
}
