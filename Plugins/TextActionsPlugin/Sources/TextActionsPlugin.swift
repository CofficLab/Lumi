import AppKit
import KernelLumi
import LumiUI
import os
import SuperLogKit
import SwiftUI

@MainActor
public final class TextActionsPlugin: LumiPlugin, SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.text-actions")
    public nonisolated static let verbose = false

    public let id = "com.coffic.lumi.plugin.text-actions"
    public var name: String {
        LumiPluginLocalization.string("Text Actions", bundle: .module)
    }
    public let order = 275
    public let policy: LumiPluginPolicy = .optIn
    public let stage: LumiPluginStage = .beta

    public init() {}

    public func onBoot(kernel: KernelLumi) async throws {}

    public func onReady(kernel: KernelLumi) async throws {
        TextActionMenuController.shared.configure(kernel: kernel)
        if TextActionsSettings.isEnabled {
            TextSelectionManager.shared.startMonitoring()
        }
    }

    public func onEnable(kernel: KernelLumi) async throws {
        TextActionMenuController.shared.configure(kernel: kernel)
        if TextActionsSettings.isEnabled {
            TextSelectionManager.shared.startMonitoring()
        }
    }

    public func onDisable(kernel: KernelLumi) async throws {
        TextSelectionManager.shared.stopMonitoring()
    }

    public func viewContainers(kernel: KernelLumi) -> [ViewContainerItem] {
        [
            ViewContainerItem(
                id: id,
                title: name,
                systemImage: "text.cursor",
                railVisibility: .unsupported,
                chatVisibility: .unsupported,
                panelHeaderVisibility: .unsupported,
                panelBottomVisibility: .unsupported
            ) {
                TextActionsSettingsView()
            }
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
    public func chatSectionItems(kernel: KernelLumi) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: KernelLumi) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: KernelLumi) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: KernelLumi) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: KernelLumi) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: KernelLumi, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: KernelLumi) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: KernelLumi) -> [AnyView] { [] }
        public func pluginAboutView(kernel: KernelLumi) -> AnyView? {
        AnyView(
            VStack(alignment: .leading, spacing: 8) {
                Label(LumiPluginLocalization.string("Text Actions", bundle: .module),
                      systemImage: "text.badge.checkmark")
                    .font(.headline)
                Text(LumiPluginLocalization.string("Quick text manipulation actions.", bundle: .module))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
        )
    }
    public func llmProviderSettingsItems(kernel: KernelLumi) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: KernelLumi) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: KernelLumi) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: KernelLumi) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: KernelLumi) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: KernelLumi, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: KernelLumi, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: KernelLumi) async {}
    public func configureEditorRuntime(kernel: KernelLumi) async {}
}
