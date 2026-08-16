import Foundation
import SwiftUI
import KernelLumi
import LumiUI
import TerminalCoreKit

@MainActor
public final class TerminalPlugin: LumiPlugin {
    nonisolated(unsafe) private var pluginsChangedObserver: NSObjectProtocol?

    public let id = "com.coffic.lumi.plugin.terminal"
    public var name: String {
        LumiPluginLocalization.string("Terminal", bundle: .module)
    }
    public let order = 279
	public let policy: LumiPluginPolicy = .optIn
    public let stage: LumiPluginStage = .beta
    public let category: LumiPluginCategory = .development

    public init() {}

    public func onBoot(kernel: KernelLumi) async throws {}

    public func onReady(kernel: KernelLumi) async throws {
        TerminalPluginBridge.editorThemeIdProvider = {
            LumiUIThemeRegistry.shared.resolvedEditorThemeId(
                colorScheme: SystemAppearanceResolver.effectiveColorScheme
            ) ?? "xcode-dark"
        }

        pluginsChangedObserver = NotificationCenter.default.addObserver(
            forName: .lumiEnabledPluginsDidChange,
            object: nil,
            queue: .main
        ) { [weak self, weak kernel] _ in
            Task { @MainActor [weak self, weak kernel] in
                guard let self, let kernel else { return }
                guard kernel.pluginManager.isPluginEnabled(id: self.id) else {
                    TerminalTabsViewModel.shared.closeAllSessions()
                    TerminalTabsViewModel.bottomPanel.closeAllSessions()
                    return
                }
            }
        }
    }

    deinit {
        if let pluginsChangedObserver {
            NotificationCenter.default.removeObserver(pluginsChangedObserver)
        }
    }

    public func viewContainers(kernel: KernelLumi) -> [ViewContainerItem] {
        [
            ViewContainerItem(
                id: id,
                title: name,
                systemImage: "terminal",
                supportsProject: true,
                railVisibility: .unsupported,
                chatVisibility: .unsupported,
                panelHeaderVisibility: .unsupported,
                panelBottomVisibility: .unsupported
            ) {
                TerminalMainView(projectProvider: kernel.project)
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
    public func panelBottomTabItems(kernel: KernelLumi) -> [PanelBottomTabItem] {
        // 底部面板的终端使用独立的 ViewModel（.bottomPanel），
        // 与 ViewContainer 的 .shared 隔离，避免同一 NSView 被两个宿主抢占。
        [
            PanelBottomTabItem(
                id: "\(id).bottom",
                title: name,
                systemImage: "terminal"
            ) {
                TerminalMainView(projectProvider: kernel.project, viewModel: .bottomPanel)
            }
        ]
    }
    public func panelRailTabItems(kernel: KernelLumi) -> [PanelRailTabItem] { [] }
    public func statusBarItems(kernel: KernelLumi) -> [StatusBarItem] { [] }
    public func chatSectionItems(kernel: KernelLumi) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: KernelLumi) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: KernelLumi) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: KernelLumi) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: KernelLumi) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: KernelLumi, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: KernelLumi) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: KernelLumi) -> [AnyView] { [] }
    public func pluginAboutView(kernel: KernelLumi) -> AnyView? {
        AnyView(TerminalAboutView())
    }
    public func pluginManualView(kernel: KernelLumi) -> AnyView? {
        AnyView(TerminalManualView())
    }
    public func llmProviderSettingsItems(kernel: KernelLumi) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: KernelLumi) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: KernelLumi) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: KernelLumi) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: KernelLumi) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: KernelLumi, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: KernelLumi, containerID: String) {}
}
