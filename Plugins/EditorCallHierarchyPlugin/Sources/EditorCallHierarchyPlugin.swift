import EditorService
import LumiKernel
import LumiUI
import SwiftUI
import os

public enum EditorCallHierarchyPanelPlugin: LumiPlugin {
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.editor-call-hierarchy-panel")

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.editor-bottom-call-hierarchy",
        displayName: LumiPluginLocalization.string("Editor Call Hierarchy", bundle: .module),
        description: LumiPluginLocalization.string("Call hierarchy panel in the editor rail and bottom area.", bundle: .module),
        order: 6,
        category: .development,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "point.3.connected.trianglepath.dotted",
    )

    @MainActor
    public static func panelBottomTabItems(context: any LumiCoreAccessing) -> [LumiPanelBottomTabItem] {
        guard context.showsPanelChrome else { return [] }
        guard let service = context.resolve(LumiEditorServicing.self)?.editorService else { return [] }

        return [
            LumiPanelBottomTabItem(
                id: "editor-bottom-call-hierarchy",
                order: info.order,
                title: LumiPluginLocalization.string("Call Hierarchy", bundle: .module),
                systemImage: iconName
            ) {
                BottomEditorCallHierarchyPanelView(service: service)
            }
        ]
    }

    @MainActor
    public static func panelRailTabItems(context: any LumiCoreAccessing) -> [LumiPanelRailTabItem] {
        guard context.showsRail else { return [] }
        guard let service = context.resolve(LumiEditorServicing.self)?.editorService else { return [] }

        return [
            LumiPanelRailTabItem(
                id: "call-hierarchy",
                order: info.order,
                title: LumiPluginLocalization.string("Call Hierarchy", bundle: .module),
                systemImage: iconName
            ) {
                BottomEditorCallHierarchyPanelView(service: service)
            }
        ]
    }
}
