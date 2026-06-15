import EditorService
import LumiCoreKit
import SwiftUI

public enum EditorBottomProblemsPanelPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .optOut
    public static let category: LumiPluginCategory = .development
    public static let iconName = "exclamationmark.bubble"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.editor-bottom-problems",
        displayName: LumiPluginLocalization.string("Editor Bottom Problems", bundle: .module),
        description: LumiPluginLocalization.string("Problems panel in the editor bottom area.", bundle: .module),
        order: 0
    )

    @MainActor
    public static func statusBarItems(context: LumiPluginContext) -> [LumiStatusBarItem] {
        guard context.showsPanelChrome,
              let editor = context.resolve(LumiEditorServicing.self),
              let presenter = context.resolve(LumiBottomPanelLayoutPresenting.self)
        else {
            return []
        }

        let editorService = editor.editorService
        let viewContainerID = context.activeSectionID
        return [
            LumiStatusBarItem(
                id: "\(info.id).diagnostics",
                title: LumiPluginLocalization.string("Problems", bundle: .module),
                systemImage: iconName,
                placement: .trailing,
                statusBarView: {
                    ProblemsDiagnosticStatusBarView(editorService: editorService) {
                        presenter.presentBottomTab(
                            id: ProblemsPanelIDs.bottomTab,
                            viewContainerID: viewContainerID
                        )
                    }
                }
            ),
        ]
    }

    @MainActor
    public static func panelBottomTabItems(context: LumiPluginContext) -> [LumiPanelBottomTabItem] {
        guard context.showsPanelChrome,
              let service = context.resolve(LumiEditorServicing.self)?.editorService
        else {
            return []
        }

        return [
            LumiPanelBottomTabItem(
                id: ProblemsPanelIDs.bottomTab,
                order: info.order,
                title: LumiPluginLocalization.string("Problems", bundle: .module),
                systemImage: "exclamationmark.bubble"
            ) {
                BottomEditorProblemsPanelView(service: service, showsHeader: false)
            }
        ]
    }

    @MainActor
    public static func aboutView(context: LumiPluginContext) -> AnyView? {
        pluginAboutView(
            features: [
                .init(icon: "exclamationmark.bubble", title: "Editor Bottom Problems", description: "Problems panel in the editor bottom area."),
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
