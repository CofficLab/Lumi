import LLMKit
import LumiKernel
import LumiUI
import SwiftUI

@MainActor
public final class FlyMuxPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.llm-provider.flymux"
    public var name: String {
        LumiPluginLocalization.string("FlyMux", bundle: .module)
    }

    public let order = 94
    public let policy: LumiPluginPolicy = .optIn
    public let stage: LumiPluginStage = .beta
    public var category: LumiPluginCategory { .llmProvider }

    public init() {}

    public func onBoot(kernel: LumiKernel) async throws {
        if let storage = kernel.storage {
            AvailabilityDiskCacheDirectoryResolver.set(
                pluginName: "LLMProviderFlyMuxPlugin",
                directory: storage.pluginDataDirectory(for: "LLMProviderFlyMuxPlugin")
            )
        }
    }

    public func onReady(kernel: LumiKernel) async throws {}

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] {
        [FlyMuxProvider(apiService: LLMAPIService(kernel: kernel))]
    }

    // MARK: - LumiPlugin stubs

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
    public func chatSectionHeaderItems(kernel: LumiKernel) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: LumiKernel) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: LumiKernel, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: LumiKernel) -> [AnyView] { [] }
    public func pluginAboutView(kernel: LumiKernel) -> AnyView? {
        AnyView(
            VStack(alignment: .leading, spacing: 8) {
                Label(LumiPluginLocalization.string("FlyMux", bundle: .module),
                      systemImage: "bolt")
                    .font(.headline)
                Text(LumiPluginLocalization.string("LLM provider for chat and agent conversations.", bundle: .module))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
        )
    }
    public func llmProviderSettingsItems(kernel: LumiKernel) -> [LLMProviderSettingsItem] { [] }
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
