import KernelLumi
import LumiUI
import SwiftUI

@MainActor
public final class EditorSearchPanelPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.editor-bottom-search"

    /// 本插件 rail 面板的稳定标识（注册为 `PanelRailTabItem.id`）。
    public nonisolated static let railTabID = "search"
    public var name: String {
        LumiPluginLocalization.string("Editor Search", bundle: .module)
    }
    public let order = 2
	public let policy: LumiPluginPolicy = .disabled
    public let stage: LumiPluginStage = .beta

    public init() {}

    public func onBoot(kernel: KernelLumi) async throws {}

    public func onReady(kernel: KernelLumi) async throws {
        // Panel items are registered in panelBottomTabItems/panelRailTabItems methods
    }


    public func panelBottomTabItems(kernel: KernelLumi) -> [PanelBottomTabItem] {
        guard let editor = kernel.editorV2 else {
            return []
        }

        return [
            PanelBottomTabItem(
                id: "editor-bottom-search",
                title: LumiPluginLocalization.string("Search", bundle: .module),
                systemImage: "magnifyingglass"
            ) {
                AnyView(BottomEditorWorkspaceSearchPanelView(viewModel: BottomWorkspaceSearchViewModel(editor: editor), showsToolbar: true))
            }
        ]
    }

    public func panelRailTabItems(kernel: KernelLumi) -> [PanelRailTabItem] {
        guard let editor = kernel.editorV2 else {
            return []
        }

        return [
            PanelRailTabItem(
                id: Self.railTabID,
                title: LumiPluginLocalization.string("Search", bundle: .module),
                systemImage: "magnifyingglass"
            ) {
                AnyView(BottomEditorWorkspaceSearchPanelView(viewModel: BottomWorkspaceSearchViewModel(editor: editor), showsToolbar: true))
            }
        ]
    }


    // MARK: - LumiPlugin stubs

    public func llmProviders(kernel: KernelLumi) -> [any LumiLLMProvider] { [] }
    public func messageRenderers(kernel: KernelLumi) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: KernelLumi) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: KernelLumi) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: KernelLumi) -> [LumiTitleToolbarItem] { [] }
    public func panelHeaderItems(kernel: KernelLumi) -> [PanelHeaderItem] { [] }
    public func statusBarItems(kernel: KernelLumi) -> [StatusBarItem] { [] }
    public func viewContainers(kernel: KernelLumi) -> [ViewContainerItem] { [] }
    public func chatSectionItems(kernel: KernelLumi) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: KernelLumi) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: KernelLumi) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: KernelLumi) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: KernelLumi) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: KernelLumi, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: KernelLumi) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: KernelLumi) -> [AnyView] { [] }
    public func pluginAboutView(kernel: KernelLumi) -> AnyView? { nil }
    public func llmProviderSettingsItems(kernel: KernelLumi) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: KernelLumi) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: KernelLumi) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: KernelLumi) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: KernelLumi) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: KernelLumi, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: KernelLumi, containerID: String) {}
}
