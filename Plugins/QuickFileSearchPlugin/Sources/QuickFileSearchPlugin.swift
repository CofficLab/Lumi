import SwiftUI
import LumiKernel
import LumiUI

@MainActor
public final class QuickFileSearchPlugin: LumiPlugin {
    public let id = "QuickFileSearch"
    public let name = "Quick File Search"
    public let order = 50
    public let policy: LumiPluginPolicy = .alwaysOn

    public init() {}

    public func onBoot(kernel: LumiKernel) async throws {}

    public func onReady(kernel: LumiKernel) async throws {
        // 注入文件选择回调：通过 EditorProviding 打开文件
        QuickFileSearchBridge.selectFileHandler = { [weak kernel] path, _ in
            Task { @MainActor in
                try? await kernel?.editorProvider?.openFile(at: path)
            }
        }

        // 注入窗口 ID 提供者（当前单窗口，返回 nil 即可）
        QuickFileSearchBridge.activeWindowIdProvider = { nil }

        // 启动快捷键监听
        FileSearchHotkeyManager.shared.startMonitoring()
    }

    // MARK: - Root Overlays

    public func rootOverlays(kernel: LumiKernel) -> [LumiRootOverlayItem] {
        [
            LumiRootOverlayItem(id: id, order: order) { content in
                FileSearchOverlay(
                    content: content,
                    projectPathProvider: { [weak kernel] in
                        kernel?.project?.currentProject?.path ?? ""
                    },
                    windowIdProvider: { nil }
                )
            },
        ]
    }

    // MARK: - Settings

    public func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem] {
        [
            SettingsTabItem(
                id: id,
                title: LumiPluginLocalization.string("Quick File Search", bundle: .module),
                systemImage: "magnifyingglass",
                order: order
            ) {
                QuickFileSearchSettingsView(
                    projectPath: kernel.project?.currentProject?.path ?? ""
                )
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
    public func panelRailTabItems(kernel: LumiKernel) -> [PanelRailTabItem] { [] }
    public func statusBarItems(kernel: LumiKernel) -> [StatusBarItem] { [] }
    public func viewContainers(kernel: LumiKernel) -> [ViewContainerItem] { [] }
    public func chatSectionItems(kernel: LumiKernel) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: LumiKernel) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: LumiKernel) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: LumiKernel) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: LumiKernel) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: LumiKernel, content: AnyView) -> AnyView { content }
    public func addSettingsView(kernel: LumiKernel) -> [AnyView] { [] }
    public func pluginAboutView(kernel: LumiKernel) -> AnyView? { nil }
    public func llmProviderSettingsItems(kernel: LumiKernel) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: LumiKernel) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func onboardingPages(kernel: LumiKernel) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: LumiKernel) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: LumiKernel, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: LumiKernel, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: LumiKernel) async {}
    public func configureEditorRuntime(kernel: LumiKernel) async {}
}
