import SwiftUI
import KernelLumi
import LumiUI

@MainActor
public final class IdleTimePlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.idle-time"
    public var name: String {
        LumiPluginLocalization.string("Idle Time", bundle: .module)
    }
    public let order = 96
    public let policy: LumiPluginPolicy = .alwaysOn
    public let stage: LumiPluginStage = .beta
    private var service: IdleTimeService?

    public init() {}

    public func onBoot(kernel: KernelLumi) async throws {
        // 与其他插件一致（参考 Projects 插件）：使用内核提供的插件数据目录，
        // 而非退回临时目录。必须在首次记录事件前设置。
        let directory = kernel.storage?.pluginDataDirectory(for: "IdleTime")
        let service = IdleTimeService(store: IdleActivityStore(directoryURL: directory))
        self.service = service
        try kernel.registerIdleTime(service)
    }

    public func onReady(kernel: KernelLumi) async throws {
        // 服务在首次记录事件时懒加载，目录已在 onBoot 设置。
    }


    // MARK: - LumiPlugin stubs

    public func llmProviders(kernel: KernelLumi) -> [any LumiLLMProvider] { [] }
    public func messageRenderers(kernel: KernelLumi) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: KernelLumi) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: KernelLumi) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: KernelLumi) -> [LumiTitleToolbarItem] { [] }
    public func panelHeaderItems(kernel: KernelLumi) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: KernelLumi) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: KernelLumi) -> [PanelRailTabItem] { [] }
    public func statusBarItems(kernel: KernelLumi) -> [StatusBarItem] {
        []
    }
    public func viewContainers(kernel: KernelLumi) -> [ViewContainerItem] { [] }
    public func chatSectionItems(kernel: KernelLumi) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: KernelLumi) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: KernelLumi) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: KernelLumi) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: KernelLumi) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: KernelLumi, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: KernelLumi) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: KernelLumi) -> [AnyView] { [] }
    public func pluginAboutView(kernel: KernelLumi) -> AnyView? {
        AnyView(IdleTimeAboutView())
    }
    public func llmProviderSettingsItems(kernel: KernelLumi) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: KernelLumi) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: KernelLumi) -> [LumiRootOverlayItem] {
        [
            LumiRootOverlayItem(id: "\(id).rootObserver") { content in
                IdleTimeRootObserver(
                    provider: kernel.idleTime,
                    projectPathProvider: { kernel.project?.currentProject?.path ?? "" },
                    content: content
                )
            }
        ]
    }
    public func onboardingPages(kernel: KernelLumi) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: KernelLumi) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: KernelLumi, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: KernelLumi, containerID: String) {}
}
