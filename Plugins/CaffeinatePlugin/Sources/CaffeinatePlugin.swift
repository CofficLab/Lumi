import SwiftUI
import KernelLumi
import LumiUI
import os
import SuperLogKit

@MainActor
public final class CaffeinatePlugin: LumiPlugin, SuperLog {
    public nonisolated static let emoji = "☕️"
    public nonisolated static let verbose: Bool = false
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.caffeinate"
    )

    public let id = "Caffeinate"
    public var name: String {
        LumiPluginLocalization.string("Caffeinate", bundle: .module)
    }
    public let order = 1
    public let policy: LumiPluginPolicy = .alwaysOn
    public let category: LumiPluginCategory = .system
    public let stage: LumiPluginStage = .beta
    public let pluginDescription = "Prevent system sleep during long-running tasks."

    public init() {}

    public func onBoot(kernel: KernelLumi) async throws {}

    public func onReady(kernel: KernelLumi) async throws {
        CaffeinateManager.shared.configure(kernel: kernel)
    }


    // MARK: - Agent Tools

    public func agentTools(kernel: KernelLumi) -> [any LumiAgentTool] {
        [
            CaffeinateActivateTool(),
            CaffeinateDeactivateTool(),
            CaffeinateStatusTool(),
            CaffeinateTurnOffDisplayTool(),
        ]
    }


    // MARK: - LumiPlugin stubs

    public func llmProviders(kernel: KernelLumi) -> [any LumiLLMProvider] { [] }
    public func messageRenderers(kernel: KernelLumi) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: KernelLumi) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: KernelLumi) -> [LumiMenuBarPopupItem] {
        [
            MenuBarPopupItem(id: "\(id).popup", order: order) {
                CaffeinateMenuBarPopupView(kernel: kernel)
            },
        ]
    }
    public func titleToolbarItems(kernel: KernelLumi) -> [LumiTitleToolbarItem] { [] }
    public func panelHeaderItems(kernel: KernelLumi) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: KernelLumi) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: KernelLumi) -> [PanelRailTabItem] { [] }
    public func statusBarItems(kernel: KernelLumi) -> [StatusBarItem] { [] }
    public func viewContainers(kernel: KernelLumi) -> [ViewContainerItem] {
//        [
//            ViewContainerItem(
//                id: "\(id).container",
//                title: LumiPluginLocalization.string("Caffeinate", bundle: .module),
//                systemImage: "cup.and.saucer.fill",
//                railVisibility: .unsupported,
//                chatVisibility: .unsupported,
//                panelHeaderVisibility: .unsupported,
//                panelBodyVisibility: .visibleByDefault,
//                panelBottomVisibility: .unsupported
//            ) {
//                CaffeinateViewContainer(kernel: kernel)
//            },
//        ]
        []
    }
    public func chatSectionItems(kernel: KernelLumi) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: KernelLumi) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: KernelLumi) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: KernelLumi) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: KernelLumi) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: KernelLumi, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: KernelLumi) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: KernelLumi) -> [AnyView] { [] }
    public func pluginAboutView(kernel: KernelLumi) -> AnyView? {
        AnyView(CaffeinateAboutView())
    }
    public func pluginManualView(kernel: KernelLumi) -> AnyView? {
        AnyView(CaffeinateManualView())
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
