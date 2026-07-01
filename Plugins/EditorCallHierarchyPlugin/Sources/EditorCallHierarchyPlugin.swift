import EditorService
import LumiCoreKit
import SwiftUI

public enum EditorCallHierarchyPanelPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .development
    public static let iconName = "point.3.connected.trianglepath.dotted"
    private static let railTabOrder = 14

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.editor-bottom-call-hierarchy",
        displayName: LumiPluginLocalization.string("Editor Call Hierarchy", bundle: .module),
        description: LumiPluginLocalization.string("Call hierarchy panel in the editor rail and bottom area.", bundle: .module),
        order: 4
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
                id: "editor-bottom-call-hierarchy",
                order: info.order,
                title: LumiPluginLocalization.string("Call Hierarchy", bundle: .module),
                systemImage: iconName
            ) {
                BottomEditorCallHierarchyPanelView(service: service, showsHeader: false)
            }
        ]
    }

    @MainActor
    public static func panelRailTabItems(context: LumiPluginContext) -> [LumiPanelRailTabItem] {
        guard context.showsRail,
              context.activeSectionID == LumiEditorPanelContainer.id,
              let service = context.resolve(LumiEditorServicing.self)?.editorService
        else {
            return []
        }

        return [
            LumiPanelRailTabItem(
                id: "call-hierarchy",
                order: railTabOrder,
                title: LumiPluginLocalization.string("Calls", bundle: .module),
                systemImage: iconName
            ) {
                BottomEditorCallHierarchyPanelView(service: service, showsHeader: false)
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
