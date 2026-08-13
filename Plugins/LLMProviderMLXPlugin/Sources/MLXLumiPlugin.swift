import LLMKit
import KernelLumi
import LumiUI
import SwiftUI

@MainActor
public final class MLXLumiPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.llm-provider.mlx"
    public var name: String {
        LumiPluginLocalization.string("MLX", bundle: .module)
    }

    public let order = 310
    public let policy: LumiPluginPolicy = .alwaysOn
    public let stage: LumiPluginStage = .beta

    public init() {}

    public func onBoot(kernel: KernelLumi) async throws {
        // 把宿主 `kernel.storage` 计算出的 plugin 数据目录注入到 bridge,
        // 让 `MLXModels.cacheRootDirectory` 走 `storage.pluginDataDirectory(for:)`
        // 这条正路,而不是每次 fallback。与其它持久化插件(FileLog / EditorSwift /
        // AppStoreConnect 等)遵循同一规律。
        Self.bootstrapFromLumiCoreIfNeeded(kernel: kernel)
    }

    public func onReady(kernel: KernelLumi) async throws {
        if let network = kernel.network {
            MLXDownloadManager.shared.configure(network: network)
        }
    }

    public func llmProviders(kernel: KernelLumi) -> [any LumiLLMProvider] {
        [
            MLXQwenProvider(),
            MLXLlamaProvider(),
            MLXMistralProvider(),
            MLXGemma4Provider(),
            MLXDeepSeekProvider(),
            MLXCoderProvider(),
            MLXMicrosoftProvider(),
        ]
    }

    // MARK: - LumiPlugin stubs

    public func messageRenderers(kernel: KernelLumi) -> [LumiMessageRendererItem] {
        [ModelNotDownloadedRenderer.item]
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
            LLMProviderLandingPage(displayName: LumiPluginLocalization.string("MLX", bundle: .module), icon: "cpu")
        )
    }

    public func llmProviderSettingsItems(kernel: KernelLumi) -> [LLMProviderSettingsItem] {
        MLXModels.seriesRegistrations.map { reg in
            LLMProviderSettingsItem(providerID: reg.providerID) { _ in
                SettingsView(seriesName: reg.seriesName)
            }
        }
    }

    public func llmProviderSettingsViews(kernel: KernelLumi) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: KernelLumi) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: KernelLumi) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: KernelLumi) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: KernelLumi, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: KernelLumi, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: KernelLumi) async {}
    public func configureEditorRuntime(kernel: KernelLumi) async {}
    public func chatSectionToolbarBarItems(kernel: KernelLumi) -> [ChatSectionToolbarBarItem] { [] }
}
