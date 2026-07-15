import EditorService
import LumiCoreKit
import LumiUI
import SwiftUI
import os

public enum EditorTerminalPanelPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .development
    public static let iconName = "terminal"
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.editor-terminal-panel")

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.editor-bottom-terminal",
        displayName: LumiPluginLocalization.string("Editor Terminal", bundle: .module),
        description: LumiPluginLocalization.string("Terminal panel in the editor bottom area.", bundle: .module),
        order: 100
    )

    @MainActor
    public static func panelBottomTabItems(context: LumiPluginContext) -> [LumiPanelBottomTabItem] {
        guard context.showsPanelChrome else { return [] }
        guard let service = context.resolve(LumiEditorServicing.self)?.editorService else { return [] }

        return [
            LumiPanelBottomTabItem(
                id: "editor-bottom-terminal",
                title: LumiPluginLocalization.string("Terminal", bundle: .module),
                systemImage: iconName
            ) {
                TerminalPanelView(service: service)
            }
        ]
    }
}
