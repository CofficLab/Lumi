import EditorService
import LumiCoreKit
import LumiUI
import SwiftUI
import os

public enum EditorStickySymbolBarHeaderPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .development
    public static let iconName = "line.3.horizontal"
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.editor-sticky-symbol-bar-header")

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.editor-sticky-symbol-bar-header",
        displayName: LumiPluginLocalization.string("Editor Sticky Symbol Bar", bundle: .module),
        description: LumiPluginLocalization.string("Sticky symbol bar for the editor panel.", bundle: .module),
        order: 85
    )

    @MainActor
    public static func panelHeaderItems(context: LumiPluginContext) -> [LumiPanelHeaderItem] {
        guard context.showsPanelChrome else {
            return []
        }
        guard let service = context.resolve(LumiEditorServicing.self)?.editorService else { return [] }

        return [
            LumiPanelHeaderItem(id: info.id) {
                StickySymbolBarView(service: service)
            }
        ]
    }
}
