import EditorService
import LumiCoreKit
import SwiftUI

public enum EditorStickySymbolBarHeaderPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .disabled
    public static let category: LumiPluginCategory = .development
    public static let iconName = "point.topleft.down.curvedto.point.bottomright.up"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.editor-sticky-symbol-bar-header",
        displayName: LumiPluginLocalization.string("Editor Sticky Symbol Bar", bundle: .module),
        description: LumiPluginLocalization.string("Current symbol breadcrumb for the editor panel.", bundle: .module),
        order: 89
    )

    @MainActor
    public static func panelHeaderItems(context: LumiPluginContext) -> [LumiPanelHeaderItem] {
        guard context.showsPanelChrome,
              let service = context.resolve(LumiEditorServicing.self)?.editorService
        else {
            return []
        }

        return [
            LumiPanelHeaderItem(id: info.id, order: info.order) {
                EditorStickySymbolBarHeaderView(service: service)
            }
        ]
    }

    @MainActor
    public static func aboutView(context: LumiPluginContext) -> AnyView? {
        pluginAboutView(
            features: [
                .init(icon: "point.topleft.down.curvedto.point.bottomright.up", title: "Editor Sticky Symbol Bar", description: "Current symbol breadcrumb for the editor panel."),
                .init(icon: "chevron.left.forwardslash.chevron.right", title: "Editor Extension", description: "Extends the built-in code editor"),
                .init(icon: "paintbrush", title: "Language Support", description: "Improves editing for specific file types")
            ],
            steps: [
                "Enable the plugin in plugin settings",
                "Open a supported file in the editor",
                "Use the editor features provided by this plugin"
            ],
            tips: [
                "Keep only the editor extensions you actively use enabled",
                "Some features depend on language tooling being available"
            ]
        )
    }

}
