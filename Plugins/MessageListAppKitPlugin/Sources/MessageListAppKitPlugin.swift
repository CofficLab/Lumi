import SwiftUI
import KernelLumi

/// Native AppKit Message List Plugin
///
/// A parallel implementation of the chat message-list view using native
/// AppKit (NSTableView) and TextKit/CoreText rendering. It is registered
/// alongside `MessageListPlugin` but ships with `.disabled` policy until
/// parity and performance gates pass.
///
/// Until then, the host application continues to render only the original
/// SwiftUI message list.
@MainActor
public final class MessageListAppKitPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.message-list-appkit"

    public var name: String {
        LumiPluginLocalization.string("Message List (AppKit)", bundle: .module)
    }

    public let order = 82

    public let policy: LumiPluginPolicy = .disabled

    public let pluginDescription: String =
        "Native AppKit message list. Disabled by default; used for evaluation alongside the SwiftUI message list."

    /// Ships as a scaffold. Will promote to `.experimental` once parity
    /// work begins and to `.stable` once the performance gate passes.
    public let stage: LumiPluginStage = .dev

    public init() {}

    public func onBoot(kernel: KernelLumi) async throws {}
    public func onReady(kernel: KernelLumi) async throws {}

    // MARK: - Chat Section Items

    public func chatSectionItems(kernel: KernelLumi) -> [ChatSectionItem] {
        [
            ChatSectionItem(
                id: id,
                placement: .stack,
                fillsRemainingHeight: true
            ) {
                MessageListAppKitBridge(kernel: kernel)
            }
        ]
    }

    // MARK: - LumiPlugin stubs (no contributions in the disabled scaffold build)

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
    public func registerEditorExtensions(into registry: AnyObject, kernel: KernelLumi) async {}
    public func configureEditorRuntime(kernel: KernelLumi) async {}
    public func editorPlugins(kernel: KernelLumi) -> [any EditorPlugin] { [] }
}
