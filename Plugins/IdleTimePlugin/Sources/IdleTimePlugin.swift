import SwiftUI
import LumiKernel
import LumiUI

@MainActor
public final class IdleTimePlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.idle-time"
    public let name = "Idle Time"
    public let order = 96
	public let policy: LumiPluginPolicy = .optOut

    public init() {}

    public func onBoot(kernel: LumiKernel) async throws {
        // 与其他插件一致（参考 Projects 插件）：使用内核提供的插件数据目录，
        // 而非退回临时目录。必须在首次记录事件前设置。
        if let storage = kernel.storage {
            IdleTimeRuntimeBridge.directoryURL = storage.pluginDataDirectory(for: "IdleTime")
        }
    }

    public func onReady(kernel: LumiKernel) async throws {
        // 服务在首次记录事件时懒加载，目录已在 onBoot 设置。
    }


    // MARK: - LumiPlugin stubs

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] { [] }
    public func subAgents(kernel: LumiKernel) -> [LumiSubAgentDefinition] { [] }
    public func messageRenderers(kernel: LumiKernel) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: LumiKernel) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: LumiKernel) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: LumiKernel) -> [LumiTitleToolbarItem] { [] }
    public func panelHeaderItems(kernel: LumiKernel) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: LumiKernel) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: LumiKernel) -> [PanelRailTabItem] { [] }
    public func statusBarItems(kernel: LumiKernel) -> [StatusBarItem] {
        []
    }
    public func viewContainers(kernel: LumiKernel) -> [ViewContainerItem] { [] }
    public func chatSectionItems(kernel: LumiKernel) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: LumiKernel) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: LumiKernel) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: LumiKernel) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: LumiKernel) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: LumiKernel, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem] {
        [
            SettingsTabItem(
                id: "\(id).settings",
                title: LumiPluginLocalization.string("Idle Time", bundle: .module),
                systemImage: "moon.zzz",
                order: order
            ) {
                IdleTimeSettingsView(kernel: kernel)
            }
        ]
    }
    public func addSettingsView(kernel: LumiKernel) -> [AnyView] { [] }
    public func pluginAboutView(kernel: LumiKernel) -> AnyView? {
        AnyView(IdleTimeAboutView())
    }
    public func llmProviderSettingsItems(kernel: LumiKernel) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: LumiKernel) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: LumiKernel) -> [LumiRootOverlayItem] {
        [
            LumiRootOverlayItem(id: "\(id).rootObserver") { content in
                IdleTimeRootObserver(
                    projectPathProvider: { kernel.project?.currentProject?.path ?? "" },
                    content: content
                )
            }
        ]
    }
    public func onboardingPages(kernel: LumiKernel) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: LumiKernel) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: LumiKernel, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: LumiKernel, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: LumiKernel) async {}
    public func configureEditorRuntime(kernel: LumiKernel) async {}
}
