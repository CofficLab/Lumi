import EditorService
import EditorTabStripPlugin
import LumiKernel
import LumiUI
import os
import SwiftUI

/// Unified code editor plugin for the Lumi activity bar.
@MainActor
public final class EditorPanelPlugin: LumiPlugin {
    nonisolated static let verbose: Bool = false
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.lumi-editor")

    public let id = "LumiEditor"
    public let name = "Code Editor"
    public let order = 77
	public let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func onBoot(kernel: LumiKernel) throws {}

    public func onReady(kernel: LumiKernel) async throws {
        guard policy.shouldRegister else { return }
        kernel.viewContainer?.register(
            ViewContainerItem(
                id: id,
                title: name,
                systemImage: "chevron.left.forwardslash.chevron.right"
            ) {
                EditorPanelHostView(kernel: kernel)
            }
        )

        // 注册 AgentTools
        kernel.toolManager?.add(GetCurrentFileTool())
        kernel.toolManager?.add(SetCurrentFileTool())
    }


    // MARK: - Workspace State

    public func workspaceVisibility(kernel: LumiKernel) -> WorkspaceVisibility {
        // Editor 容器：显示 rail + content + panel，不显示 chat
        WorkspaceVisibility(
            rail: true,
            chat: false,
            content: true,
            activityBar: true,
            panel: true
        )
    }

    public func onContainerActivated(kernel: LumiKernel, containerID: String) {
        guard containerID == id else { return }
        kernel.workspaceState?.applyVisibility(
            rail: true,
            chat: false,
            content: true,
            activityBar: true,
            panel: true
        )
    }

    public func boot(kernel: LumiKernel) async throws {}

    // MARK: - LumiPlugin stubs

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] { [] }
    public func subAgents(kernel: LumiKernel) -> [LumiSubAgentDefinition] { [] }
    public func sendMiddlewares(kernel: LumiKernel) -> [any LumiSendMiddleware] { [] }
    public func messageRenderers(kernel: LumiKernel) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: LumiKernel) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: LumiKernel) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: LumiKernel) -> [LumiTitleToolbarItem] { [] }
    public func panelHeaderItems(kernel: LumiKernel) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: LumiKernel) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: LumiKernel) -> [PanelRailTabItem] { [] }
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
    public func registerEditorExtensions(into registry: AnyObject, kernel: LumiKernel) async {}
    public func configureEditorRuntime(kernel: LumiKernel) async {}
}