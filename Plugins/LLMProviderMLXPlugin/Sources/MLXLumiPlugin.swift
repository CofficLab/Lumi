import SwiftUI
import LLMKit
import LumiKernel
import LumiKernel
import LumiUI

@MainActor
public final class MLXLumiPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.llm-provider.mlx"
    public var name: String {
        LumiPluginLocalization.string("MLX", bundle: .module)
    }
    public let order = 310
    public let policy: LumiPluginPolicy = .alwaysOn

    public init() {}

    public func onBoot(kernel: LumiKernel) async throws {}

    public func onReady(kernel: LumiKernel) async throws {
        if let network = kernel.network {
            MLXDownloadManager.shared.configure(network: network)
        }
    }


    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] {
        [MLXLumiProvider()]
    }


    // MARK: - LumiPlugin stubs

    public func subAgents(kernel: LumiKernel) -> [LumiSubAgentDefinition] { [] }
    public func messageRenderers(kernel: LumiKernel) -> [LumiMessageRendererItem] {
        [ModelNotDownloadedRenderer.item]
    }
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
    public func chatSectionHeaderItems(kernel: LumiKernel) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: LumiKernel) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: LumiKernel, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: LumiKernel) -> [AnyView] { [] }
    public func pluginAboutView(kernel: LumiKernel) -> AnyView? { nil }
    /// 注册 MLX 专属设置页。
    ///
    /// 4.x 时代这项能力通过 `llmProviderSettingsViews` 提供；当前设置页消费
    /// `LLMProviderSettingsItem`，迁移时若继续返回空数组，MLX 仍能正常对话，
    /// 但“设置 → 本地供应商”里不会出现模型下载、暂停/恢复和缓存管理界面。
    public func llmProviderSettingsItems(kernel: LumiKernel) -> [LLMProviderSettingsItem] {
        [
            LLMProviderSettingsItem(providerID: "mlx") { _ in
                MLXLocalProviderSettingsView()
            },
        ]
    }
    public func llmProviderSettingsViews(kernel: LumiKernel) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: LumiKernel) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: LumiKernel) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: LumiKernel) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: LumiKernel, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: LumiKernel, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: LumiKernel) async {}
    public func configureEditorRuntime(kernel: LumiKernel) async {}
    public func chatSectionToolbarBarItems(kernel: LumiKernel) -> [ChatSectionToolbarBarItem] { [] }
}
