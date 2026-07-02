import EditorService
import LumiCoreKit
import LumiUI
import SwiftUI

public enum EditorSymbolsPanelPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .development
    public static let iconName = "list.bullet.rectangle"
    private static let railTabOrder = 13

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.editor-bottom-symbols",
        displayName: LumiPluginLocalization.string("Editor Symbols", bundle: .module),
        description: LumiPluginLocalization.string("Symbols panel in the editor rail and bottom area.", bundle: .module),
        order: 3
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
                id: "editor-bottom-symbols",
                order: info.order,
                title: LumiPluginLocalization.string("Symbols", bundle: .module),
                systemImage: iconName
            ) {
                BottomEditorWorkspaceSymbolsPanelView(service: service, showsHeader: false)
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
                id: "symbols",
                order: railTabOrder,
                title: LumiPluginLocalization.string("Symbols", bundle: .module),
                systemImage: "number"
            ) {
                BottomEditorWorkspaceSymbolsPanelView(service: service, showsHeader: false)
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
