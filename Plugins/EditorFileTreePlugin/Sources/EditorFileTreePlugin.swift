import Foundation
import os
import SwiftUI
import LumiKernel
import LumiUI
import SuperLogKit

/// File tree plugin (native SwiftUI rendering).
///
/// The class name `EditorFileTreePanelPlugin` is kept for source compatibility with
/// `TreeView` / `NodeView` / services that reference its static feature flags and
/// `SuperLog` configuration.
@MainActor
public final class EditorFileTreePanelPlugin: LumiPlugin {

    // MARK: - Feature flags

    /// 是否启用 Git 状态显示功能（禁用可提升文件树滚动性能）。
    public nonisolated static let gitStatusEnabled: Bool = true

    /// 是否显示 Swift Package Dependencies 区域。
    public nonisolated static let packageDependenciesEnabled: Bool = true

    /// 是否启用文件树行 hover 高亮。
    public nonisolated static let hoverHighlightEnabled: Bool = true

    /// 是否启用文件树行拖拽和目录 drop target。
    public nonisolated static let dragAndDropEnabled: Bool = true

    /// 是否启用右键菜单、重命名、新建、删除等上下文操作入口。
    public nonisolated static let contextMenuEnabled: Bool = true

    /// 是否显示缩进参考线。
    public nonisolated static let indentGuidesEnabled: Bool = true

    /// 是否启用定位文件时的闪烁高亮。
    public nonisolated static let flashHighlightEnabled: Bool = true

    /// 是否启用中键点击文件预览。
    public nonisolated static let middleClickPreviewEnabled: Bool = true

    /// 是否启用活动文件图标主题解析；关闭后只使用默认静态图标主题。
    public nonisolated static let activeFileIconThemeEnabled: Bool = true

    // MARK: - SuperLog Configuration

    public nonisolated static let emoji = "🌳"
    public nonisolated static let verbose: Bool = false
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.file-tree"
    )

    // MARK: - LumiPlugin identity

    public let id = "com.coffic.lumi.plugin.editor-rail-file-tree"
    public let name = "Editor File Tree"
    public let order = 50
    public let policy: LumiPluginPolicy = .optOut

    public init() {}

    public func onBoot(kernel: LumiKernel) async throws {}

    public func onReady(kernel: LumiKernel) async throws {
        if let lumiCore = kernel.lumiCore {
            EditorFileTreePanelPlugin.bootstrapFromLumiCoreIfNeeded(context: lumiCore)
        }
    }

    public func panelRailTabItems(kernel: LumiKernel) -> [PanelRailTabItem] {
        guard let lumiCore = kernel.lumiCore else { return [] }
        return [
            PanelRailTabItem(
                id: "explorer",
                title: LumiPluginLocalization.string("Explorer", bundle: .module),
                systemImage: "folder"
            ) {
                TreeView(lumiCore: lumiCore)
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
