import KernelLumi
import SuperLogKit
import LumiUI
import os
import SwiftUI

/// Brew Manager 插件
///
/// 向 KernelLumi 注册 Homebrew 包管理功能：
/// - ViewContainer：侧边栏包管理视图
@MainActor
public final class BrewManagerPlugin: LumiPlugin, SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.brew-manager")
    public nonisolated static let emoji = "🍺"
    nonisolated static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.brew-manager"
    public var name: String { LumiPluginLocalization.string("Package Management", bundle: .module) }
    public var pluginDescription: String { LumiPluginLocalization.string("Manage Homebrew packages and casks", bundle: .module) }
    public let order = 260
    public let policy: LumiPluginPolicy = .optIn
    public let stage: LumiPluginStage = .beta

    // MARK: - Initialization

    public init() {}

    // MARK: - LumiPlugin

    public func onBoot(kernel: KernelLumi) async throws {}

    public func onReady(kernel: KernelLumi) async throws {}

    public func viewContainers(kernel: KernelLumi) -> [ViewContainerItem] {
        [
            ViewContainerItem(
                id: id,
                title: name,
                systemImage: "mug.fill",
                railVisibility: .unsupported,
                chatVisibility: .unsupported,
                panelHeaderVisibility: .unsupported,
                panelBottomVisibility: .unsupported
            ) {
                BrewManagerView()
            },
        ]
    }


    // MARK: - LumiPlugin stubs

    public func llmProviders(kernel: KernelLumi) -> [any LumiLLMProvider] { [] }
    public func messageRenderers(kernel: KernelLumi) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: KernelLumi) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: KernelLumi) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: KernelLumi) -> [LumiTitleToolbarItem] {
        [
            LumiTitleToolbarItem(
                id: "\(id).refresh",
                title: LumiPluginLocalization.string("Refresh", bundle: .module),
                placement: .trailing,
                order: 260
            ) {
                BrewRefreshButton(kernel: kernel, containerID: self.id)
            },
        ]
    }
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
        AnyView(AboutView())
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

extension Notification.Name {
    static let brewManagerRefreshRequested = Notification.Name("BrewManagerPlugin.refreshRequested")
}

private struct BrewRefreshButton: View {
    let kernel: KernelLumi
    let containerID: String

    @State private var isVisible = false

    var body: some View {
        Group {
            if isVisible {
                AppIconButton(systemImage: "arrow.clockwise") {
                    NotificationCenter.default.post(name: .brewManagerRefreshRequested, object: nil)
                }
                .help(LumiPluginLocalization.string("Refresh", bundle: .module))
            }
        }
        .onAppear {
            isVisible = kernel.workspace?.activeViewContainerID == containerID
        }
        .onActiveViewContainerIDDidChange { activeID in
            isVisible = activeID == containerID
        }
    }
}
