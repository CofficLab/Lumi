import EditorService
import LumiCoreKit
import LumiUI
import SwiftUI

public enum EditorProblemsPanelPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .development
    public static let iconName = "exclamationmark.bubble"
    private static let railTabOrder = 10

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.editor-bottom-problems",
        displayName: LumiPluginLocalization.string("Editor Problems", bundle: .module),
        description: LumiPluginLocalization.string("Problems panel in the editor rail and bottom area.", bundle: .module),
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
                systemImage: iconName
            ) {
                BottomEditorProblemsPanelView(service: service, showsHeader: false)
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
                id: "problems",
                order: railTabOrder,
                title: LumiPluginLocalization.string("Problems", bundle: .module),
                systemImage: iconName
            ) {
                BottomEditorProblemsPanelView(service: service, showsHeader: false)
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
