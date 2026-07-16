import EditorService
import LumiCoreKit
import LumiUI
import SwiftUI
import SuperLogKit

/// Swift / Xcode 集成插件：scheme 工具栏与 Agent 工具。
public enum EditorSwiftPlugin: LumiPlugin {

    /// Code Editor 面板 section id（与 `EditorPanelPlugin.info.id` 一致）。
    private static let editorPanelSectionID = "LumiEditor"

    public static let info = LumiPluginInfo(
        id: "EditorSwiftIntegration",
        displayName: LumiPluginLocalization.string("Swift Integration", bundle: .module),
        description: LumiPluginLocalization.string("Provides scheme toolbar, Xcode project integration, and Swift agent tools.", bundle: .module),
        order: 5,
        category: .development,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "swift",
    )

    @MainActor
    public static func titleToolbarItems(context: LumiPluginContext) -> [LumiTitleToolbarItem] {
        guard context.activeSectionID == editorPanelSectionID,
              context.resolve(LumiEditorServicing.self) != nil
        else {
            return []
        }

        configureBuildOutputPresentation(context: context)

        return [
            LumiTitleToolbarItem(
                id: "\(info.id).xcode-scheme",
                title: LumiPluginLocalization.string("Xcode Scheme", bundle: .module),
                placement: .leading
            ) {
                XcodeProjectStatusBar(viewModel: EditorSwiftWindowScopeRegistry.activeStatusBarViewModel)
            }
        ]
    }

    @MainActor
    public static func panelBottomTabItems(context: LumiPluginContext) -> [LumiPanelBottomTabItem] {
        guard context.showsPanelChrome,
              context.activeSectionID == editorPanelSectionID,
              context.resolve(LumiEditorServicing.self) != nil
        else {
            return []
        }

        configureBuildOutputPresentation(context: context)

        return [
            LumiPanelBottomTabItem(
                id: SwiftBuildPanelIDs.bottomTab,
                order: info.order,
                title: LumiPluginLocalization.string("Build", bundle: .module),
                systemImage: "play.fill"
            ) {
                SwiftBuildOutputView(
                    buildRunManager: EditorSwiftWindowScopeRegistry.activeBuildRunManager
                )
            }
        ]
    }

    @MainActor
    public static func agentTools(context: LumiPluginContext) -> [any LumiAgentTool] {
        [
            AddSwiftPackageTool(),
            ListSwiftPackagesTool(),
            GenerateXcodeProjectTool(),
        ]
    }

    @MainActor
    private static func configureBuildOutputPresentation(context: LumiPluginContext) {
        guard context.showsPanelChrome,
              let layoutState = context.lumiCore?.layoutState
        else {
            return
        }

        let tabID = SwiftBuildPanelIDs.bottomTab
        let viewContainerID = context.activeSectionID
        EditorSwiftWindowScopeRegistry.activeBuildRunManager.onPresentOutput = {
            layoutState.presentBottomTab(id: tabID, viewContainerID: viewContainerID)
        }
    }
}
