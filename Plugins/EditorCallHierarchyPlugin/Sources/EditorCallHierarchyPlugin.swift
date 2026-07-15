import EditorService
import LumiCoreKit
import LumiUI
import SwiftUI
import os

public enum EditorCallHierarchyPanelPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .development
    public static let iconName = "point.3.connected.trianglepath.dotted"
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.editor-call-hierarchy-panel")

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.editor-bottom-call-hierarchy",
        displayName: LumiPluginLocalization.string("Editor Call Hierarchy", bundle: .module),
        description: LumiPluginLocalization.string("Call hierarchy panel in the editor rail and bottom area.", bundle: .module),
        order: 6
    )

    @MainActor
    public static func panelBottomTabItems(context: LumiPluginContext) -> [LumiPanelBottomTabItem] {
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
    public static func panelRailTabItems(context: LumiPluginContext) -> [LumiPanelRailTabItem] {
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
