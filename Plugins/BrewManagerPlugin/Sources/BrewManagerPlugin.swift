import LumiKernel
import SuperLogKit
import LumiUI
import os
import SwiftUI

/// Brew Manager 插件
///
/// 向 LumiKernel 注册 Homebrew 包管理功能：
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

    public func onBoot(kernel: LumiKernel) async throws {}

    public func onReady(kernel: LumiKernel) async throws {}

    public func viewContainers(kernel: LumiKernel) -> [ViewContainerItem] {
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

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] { [] }
    public func messageRenderers(kernel: LumiKernel) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: LumiKernel) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: LumiKernel) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: LumiKernel) -> [LumiTitleToolbarItem] {
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
    public func panelHeaderItems(kernel: LumiKernel) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: LumiKernel) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: LumiKernel) -> [PanelRailTabItem] { [] }
    public func statusBarItems(kernel: LumiKernel) -> [StatusBarItem] { [] }
    public func chatSectionItems(kernel: LumiKernel) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: LumiKernel) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: LumiKernel) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: LumiKernel) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: LumiKernel) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: LumiKernel, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: LumiKernel) -> [AnyView] { [] }
    public func pluginAboutView(kernel: LumiKernel) -> AnyView? {
        AnyView(AboutView())
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
}

extension Notification.Name {
    static let brewManagerRefreshRequested = Notification.Name("BrewManagerPlugin.refreshRequested")
}

private struct BrewRefreshButton: View {
    let kernel: LumiKernel
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
