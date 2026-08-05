import LLMKit
import LumiKernel
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

    public init() {}

    public func onBoot(kernel: LumiKernel) async throws {
        // 把宿主 `kernel.storage` 计算出的 plugin 数据目录注入到 bridge,
        // 让 `MLXModels.cacheRootDirectory` 走 `storage.pluginDataDirectory(for:)`
        // 这条正路,而不是每次 fallback。与其它持久化插件(FileLog / EditorSwift /
        // AppStoreConnect 等)遵循同一规律。
        Self.bootstrapFromLumiCoreIfNeeded(kernel: kernel)
    }

    public func onReady(kernel: LumiKernel) async throws {
        if let network = kernel.network {
            MLXDownloadManager.shared.configure(network: network)
        }
    }

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] {
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

    public func llmProviderSettingsItems(kernel: LumiKernel) -> [LLMProviderSettingsItem] {
        MLXModels.seriesRegistrations.map { reg in
            LLMProviderSettingsItem(providerID: reg.providerID) { _ in
                SettingsView()
            }
        }
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
