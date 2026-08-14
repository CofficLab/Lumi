import KernelLumi
import SwiftUI

@MainActor
public final class OnboardingPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.onboarding"
    public var name: String {
        LumiPluginLocalization.string("Onboarding", bundle: .module)
    }
    public let order = 10
    public let policy: LumiPluginPolicy = .alwaysOn
    public let stage: LumiPluginStage = .beta

    public init() {}

    public func onBoot(kernel: KernelLumi) async throws {
        OnboardingPlugin.bootstrapFromLumiCoreIfNeeded(kernel: kernel)
    }

    public func onReady(kernel: KernelLumi) async throws {
        OnboardingPlugin.initializeViewModel(kernel: kernel)
    }

    public func onboardingPages(kernel: KernelLumi) -> [OnboardingPageItem] {
        [
            OnboardingPageItem(id: "onboarding-welcome") {
                WelcomePage()
            },
            OnboardingPageItem(id: "onboarding-ai-setup") {
                AISetupPage(kernel: kernel)
            },
        ]
    }

    public func rootOverlays(kernel: KernelLumi) -> [LumiRootOverlayItem] {
        [
            LumiRootOverlayItem(
                id: "onboarding-root-overlay",
                order: 10,
                wrap: { content in
                    AnyView(RootOverlay(content: content, kernel: kernel))
                }
            ),
        ]
    }

    public func llmProviders(kernel: KernelLumi) -> [any LumiLLMProvider] { [] }
    public func messageRenderers(kernel: KernelLumi) -> [LumiMessageRendererItem] { [] }
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
    public func chatSectionToolbarBarItems(kernel: KernelLumi) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: KernelLumi) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: KernelLumi) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: KernelLumi, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: KernelLumi) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: KernelLumi) -> [AnyView] { [] }
    public func pluginAboutView(kernel: KernelLumi) -> AnyView? { nil }
    public func llmProviderSettingsItems(kernel: KernelLumi) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: KernelLumi) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func agentTools(kernel: KernelLumi) -> [any LumiAgentTool] { [] }
    public func logoItems(kernel: KernelLumi) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: KernelLumi, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: KernelLumi, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: KernelLumi) async {}
    public func configureEditorRuntime(kernel: KernelLumi) async {}
}
