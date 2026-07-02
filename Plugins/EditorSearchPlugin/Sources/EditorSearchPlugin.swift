import EditorService
import LumiCoreKit
import LumiUI
import SwiftUI

public enum EditorSearchPanelPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .development
    public static let iconName = "magnifyingglass"
    private static let railTabOrder = 12

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.editor-bottom-search",
        displayName: LumiPluginLocalization.string("Editor Search", bundle: .module),
        description: LumiPluginLocalization.string("Search panel in the editor rail and bottom area.", bundle: .module),
        order: 2
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
                id: "editor-bottom-search",
                order: info.order,
                title: LumiPluginLocalization.string("Search", bundle: .module),
                systemImage: iconName
            ) {
                BottomEditorWorkspaceSearchPanelView(service: service, showsToolbar: true)
            }
        ]
    }

    @MainActor
    public static func panelRailTabItems(context: LumiPluginContext) -> [LumiPanelRailTabItem] {
        guard context.showsRail,
              let service = context.resolve(LumiEditorServicing.self)?.editorService
        else {
            return []
        }

        return [
            LumiPanelRailTabItem(
                id: "search",
                order: railTabOrder,
                title: LumiPluginLocalization.string("Search", bundle: .module),
                systemImage: iconName
            ) {
                BottomEditorWorkspaceSearchPanelView(service: service, showsToolbar: true)
            }
        ]
    }

    @MainActor
    public static func aboutView(context: LumiPluginContext) -> AnyView? {
        AnyView(
            VStack(alignment: .leading, spacing: 16) {
                Text(info.displayName)
                    .font(.title2.weight(.semibold))
                Text(info.description)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        )
    }
}
