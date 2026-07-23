import Foundation
import os
import SwiftUI
import LumiKernel
import LumiUI

/// File tree plugin V2 (NSCollectionView bridge).
///
/// Provides a high-performance file tree rendered via AppKit's NSCollectionView
/// bridge (`TreeViewV2` / `FileTreeNSViewBridge`). Static feature flags and the
/// SuperLog logger exposed here are consumed by `TreeViewV2` and the supporting
/// services in `Services/`.
@MainActor
public final class EditorFileTreeV2Plugin: LumiPlugin {

    // MARK: - Feature flags

    /// 是否启用 Git 状态显示功能（禁用可提升文件树滚动性能）。
    public nonisolated static let gitStatusEnabled: Bool = true

    /// 是否启用文件树行拖拽和目录 drop target。
    public nonisolated static let dragAndDropEnabled: Bool = true

    /// 是否启用定位文件时的闪烁高亮。
    public nonisolated static let flashHighlightEnabled: Bool = true

    // MARK: - SuperLog Configuration

    public nonisolated static let emoji = "🌲"
    public nonisolated static let verbose: Bool = false
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.file-tree-v2"
    )

    // MARK: - LumiPlugin identity

    public let id = "com.coffic.lumi.plugin.editor-file-tree-v2"
    public let name = "Editor File Tree V2"
    public let order = 51
    public let policy: LumiPluginPolicy = .optOut

    public init() {}

    public func onBoot(kernel: LumiKernel) async throws {}

    public func onReady(kernel: LumiKernel) async throws {
        if let lumiCore = kernel.lumiCore {
            EditorFileTreeV2Plugin.bootstrapFromLumiCoreIfNeeded(context: lumiCore)
        }
    }

    public func panelRailTabItems(kernel: LumiKernel) -> [PanelRailTabItem] {
        guard let lumiCore = kernel.lumiCore else { return [] }
        return [
            PanelRailTabItem(
                id: "explorer-v2",
                title: LumiPluginLocalization.string("Explorer V2", bundle: .module),
                systemImage: "square.grid.2x2.fill"
            ) {
                TreeViewV2(lumiCore: lumiCore)
            },
        ]
    }


    // MARK: - LumiPlugin stubs

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] { [] }
    public func subAgents(kernel: LumiKernel) -> [LumiSubAgentDefinition] { [] }
    public func messageRenderers(kernel: LumiKernel) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: LumiKernel) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: LumiKernel) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: LumiKernel) -> [LumiTitleToolbarItem] { [] }
    public func panelHeaderItems(kernel: LumiKernel) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: LumiKernel) -> [PanelBottomTabItem] { [] }
    public func statusBarItems(kernel: LumiKernel) -> [StatusBarItem] { [] }
    public func viewContainers(kernel: LumiKernel) -> [ViewContainerItem] { [] }
    public func chatSectionItems(kernel: LumiKernel) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: LumiKernel) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: LumiKernel) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: LumiKernel) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: LumiKernel) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: LumiKernel, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: LumiKernel) -> [AnyView] { [] }
    public func pluginAboutView(kernel: LumiKernel) -> AnyView? { nil }
    public func llmProviderSettingsItems(kernel: LumiKernel) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: LumiKernel) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: LumiKernel) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: LumiKernel) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: LumiKernel) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: LumiKernel, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func workspaceVisibility(kernel: LumiKernel) -> WorkspaceVisibility { WorkspaceVisibility() }
    public func onContainerActivated(kernel: LumiKernel, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: LumiKernel) async {}
    public func configureEditorRuntime(kernel: LumiKernel) async {}
}
