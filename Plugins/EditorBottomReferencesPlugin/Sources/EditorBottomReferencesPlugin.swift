import EditorService
import LumiCoreKit
import SwiftUI

public enum EditorBottomReferencesPanelPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .optOut
    public static let category: LumiPluginCategory = .development
    public static let iconName = "arrow.triangle.branch"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.editor-bottom-references",
        displayName: LumiPluginLocalization.string("Editor Bottom References", bundle: .module),
        description: LumiPluginLocalization.string("References panel in the editor bottom area.", bundle: .module),
        order: 1
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
                id: "editor-bottom-references",
                order: info.order,
                title: LumiPluginLocalization.string("References", bundle: .module),
                systemImage: "arrow.triangle.branch"
            ) {
                BottomEditorReferencesWorkspacePanelView(service: service, showsHeader: false)
            }
        ]
    }

    @MainActor
    public static func aboutView(context: LumiPluginContext) -> AnyView? {
        pluginAboutView(
            features: [
                .init(icon: "arrow.triangle.branch", title: "Editor Bottom References", description: "References panel in the editor bottom area."),
                .init(icon: "rectangle.bottomhalf.inset.filled", title: "Bottom Panel", description: "Adds a tab to the editor bottom panel"),
                .init(icon: "doc.text.magnifyingglass", title: "Editor Context", description: "Works with the file currently open in the editor")
            ],
            steps: [
                "Enable the plugin in plugin settings",
                "Open a file in the code editor",
                "Open the bottom panel tab provided by this plugin"
            ],
            tips: [
                "Use the status bar shortcut when available",
                "Disable the plugin if you prefer a cleaner editor layout"
            ]
        )
    }

}
