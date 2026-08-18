import KernelLumi
import LumiUI
import SwiftUI

@MainActor
public final class AliyunPlugin: LumiPlugin {
    public static let rendererOrder = 305

    public let id = "com.coffic.lumi.plugin.llm-provider.aliyun"
    public var name: String {
        LumiPluginLocalization.string("阿里云", bundle: .module)
    }

    public let order = 105
    public let policy: LumiPluginPolicy = .alwaysOn
    public let stage: LumiPluginStage = .beta
    public var category: LumiPluginCategory { .llmProvider }

    public init() {}

    public func onBoot(kernel: KernelLumi) async throws {
        if let storage = kernel.storage {
            AvailabilityDiskCacheDirectoryResolver.set(
                pluginName: "LLMProviderAliyun",
                directory: storage.pluginDataDirectory(for: "LLMProviderAliyun")
            )
        }
    }

    public func onReady(kernel: KernelLumi) async throws {}

    public func llmProviders(kernel: KernelLumi) -> [any LumiLLMProvider] {
        let network = kernel.network
        return [
            CodingPlanProvider(network: network),
            TokenPlanProvider(network: network),
        ]
    }

    // MARK: - LumiPlugin stubs

    public func messageRenderers(kernel: KernelLumi) -> [LumiMessageRendererItem] {
        [
            ApiKeyMissingRenderer.item,
            Http401Renderer.item,
            Http403Renderer.item,
            HttpErrorRenderer.item,
            RequestFailedRenderer.item,
        ]
    }

    public func menuBarContentItems(kernel: KernelLumi) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: KernelLumi) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: KernelLumi) -> [LumiTitleToolbarItem] { [] }
    public func panelHeaderItems(kernel: KernelLumi) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: KernelLumi) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: KernelLumi) -> [PanelRailTabItem] { [] }
    public func statusBarItems(kernel: KernelLumi) -> [StatusBarItem] { [] }
    public func viewContainers(kernel: KernelLumi) -> [ViewContainerItem] { [] }
    public func chatSectionItems(kernel: KernelLumi) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: KernelLumi) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionHeaderItems(kernel: KernelLumi) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: KernelLumi) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: KernelLumi, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: KernelLumi) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: KernelLumi) -> [AnyView] { [] }
    public func pluginAboutView(kernel: KernelLumi) -> AnyView? {
        AnyView(
            LLMProviderLandingPage(displayName: LumiPluginLocalization.string("阿里云 CodingPlan", bundle: .module), icon: "cloud")
        )
    }

    public func llmProviderSettingsItems(kernel: KernelLumi) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: KernelLumi) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: KernelLumi) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: KernelLumi) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: KernelLumi) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: KernelLumi, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: KernelLumi, containerID: String) {}
    public func chatSectionToolbarBarItems(kernel: KernelLumi) -> [ChatSectionToolbarBarItem] { [] }
}
