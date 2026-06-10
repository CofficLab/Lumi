import EditorBottomProblemsPlugin
import EditorService
import LumiCoreKit
import LumiUI
import SwiftUI

public enum EditorRailProblemsPanelPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .optOut
    public static let category: LumiPluginCategory = .development
    public static let iconName = "exclamationmark.bubble"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.editor-rail-problems",
        displayName: "Editor Rail Problems",
        description: "Problems tab in the editor rail.",
        order: 10
    )

    @MainActor
    public static func editorRailTabItems(context: LumiPluginContext) -> [LumiEditorRailTabItem] {
        guard context.showsPanelChrome,
              let service = context.resolve(LumiEditorServicing.self)?.editorService
        else {
            return []
        }

        return [
            LumiEditorRailTabItem(
                id: "problems",
                order: info.order,
                title: String(localized: "Problems", bundle: .module),
                systemImage: "exclamationmark.bubble"
            ) {
                BottomEditorProblemsPanelView(service: service, showsHeader: false)
            }
        ]
    }
}
