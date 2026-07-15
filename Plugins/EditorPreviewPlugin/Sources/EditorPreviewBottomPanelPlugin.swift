import LumiCoreKit
import LumiUI
import SwiftUI

public enum EditorPreviewBottomPanelPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .development
    public static let iconName = "rectangle.inset.filled"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.editor-bottom-inline-preview",
        displayName: LumiPluginLocalization.string("Inline Preview", bundle: .module),
        description: LumiPluginLocalization.string("Embedded preview in the editor bottom area.", bundle: .module),
        order: 84
    )

    @MainActor
    public static func panelBottomTabItems(context: LumiPluginContext) -> [LumiPanelBottomTabItem] {
        guard context.showsPanelChrome else { return [] }
        guard let lumiCore = context.lumiCore else { return [] }

        return [
            LumiPanelBottomTabItem(
                id: "editor-bottom-inline-preview",
                order: info.order,
                title: LumiPluginLocalization.string("Preview", bundle: .module),
                systemImage: "rectangle.inset.filled"
            ) {
                EditorPreviewDetailView(lumiCore: lumiCore)
            }
        ]
    }
}
