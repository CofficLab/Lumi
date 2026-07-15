import EditorService
import LumiCoreKit
import LumiUI
import SwiftUI
import os

public enum EditorPreviewBottomPanelPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .development
    public static let iconName = "eye"
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.editor-preview-bottom-panel")

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.editor-bottom-preview",
        displayName: LumiPluginLocalization.string("Editor Preview", bundle: .module),
        description: LumiPluginLocalization.string("Preview panel in the editor bottom area.", bundle: .module),
        order: 84
    )

    @MainActor
    public static func panelBottomTabItems(context: LumiPluginContext) -> [LumiPanelBottomTabItem] {
        guard context.showsPanelChrome else { return [] }
        guard let service = context.resolve(LumiEditorServicing.self)?.editorService else { return [] }

        return [
            LumiPanelBottomTabItem(
                id: "editor-bottom-preview",
                title: LumiPluginLocalization.string("Preview", bundle: .module),
                systemImage: iconName
            ) {
                PreviewPanelView(service: service)
            }
        ]
    }
}
