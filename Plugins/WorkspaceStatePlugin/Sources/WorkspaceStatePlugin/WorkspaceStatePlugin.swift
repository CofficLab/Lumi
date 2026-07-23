import Foundation
import LumiKernel
import SwiftUI

/// 工作区状态插件
///
/// 提供 `WorkspaceStateProviding` 服务的默认实现，集中管理工作区可见性。
/// 最早注册（order=1），保证其他插件的 `onContainerActivated` 回调有 workspaceState 可用。
@MainActor
public final class WorkspaceStatePlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.workspace-state"
    public let name = "WorkspaceState Plugin"
    public let order = 1
    public let policy: LumiPluginPolicy = .alwaysOn

    /// 由 PluginManagerProvider 持有，供其他插件通知容器激活
    public weak var instance: DefaultWorkspaceStateProviding?

    public init() {}

    public func onBoot(kernel: LumiKernel) async throws {}

    public func onReady(kernel: LumiKernel) async throws {
        let service = DefaultWorkspaceStateProviding()
        kernel.registerWorkspaceStateService(service)
        self.instance = service
    }

    // MARK: - LumiPlugin stubs

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] { [] }
    public func subAgents(kernel: LumiKernel) -> [LumiSubAgentDefinition] { [] }
    public func sendMiddlewares(kernel: LumiKernel) -> [any LumiSendMiddleware] { [] }
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
    public func chatSectionToolbarBarItems(kernel: LumiKernel) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: LumiKernel) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: LumiKernel) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: LumiKernel, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: LumiKernel) -> [AnyView] { [] }
    public func pluginAboutView(kernel: LumiKernel) -> AnyView? { nil }
    public func llmProviderSettingsItems(kernel: LumiKernel) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: LumiKernel) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: LumiKernel) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: LumiKernel) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: LumiKernel) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: LumiKernel, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func workspaceVisibility(kernel: LumiKernel) -> WorkspaceVisibility { WorkspaceVisibility() }
    public func onContainerActivated(kernel: LumiKernel, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: LumiKernel) async {}
    public func configureEditorRuntime(kernel: LumiKernel) async {}

}

/// `WorkspaceStateProviding` 的默认实现
@MainActor
public final class DefaultWorkspaceStateProviding: WorkspaceStateProviding, ObservableObject {
    private var _isRailVisible = true
    private var _isChatVisible = true
    private var _isContentVisible = true
    private var _isActivityBarVisible = true
    private var _isPanelVisible = true
    private var _activeContainerID: String?

    /// 变更通知回调列表（由 PluginManagerProvider 注入）
    private var observers: [(String) -> Void] = []

    public init() {}

    // MARK: - Read

    public var isRailVisible: Bool { _isRailVisible }
    public var isChatVisible: Bool { _isChatVisible }
    public var isContentVisible: Bool { _isContentVisible }
    public var isActivityBarVisible: Bool { _isActivityBarVisible }
    public var isPanelVisible: Bool { _isPanelVisible }
    public var activeContainerID: String? { _activeContainerID }

    // MARK: - Commands

    public func setRailVisible(_ visible: Bool) { _isRailVisible = visible }
    public func setChatVisible(_ visible: Bool) { _isChatVisible = visible }
    public func setContentVisible(_ visible: Bool) { _isContentVisible = visible }
    public func setActivityBarVisible(_ visible: Bool) { _isActivityBarVisible = visible }
    public func setPanelVisible(_ visible: Bool) { _isPanelVisible = visible }

    public func activateContainer(id: String) {
        guard _activeContainerID != id else { return }
        _activeContainerID = id
        for observer in observers {
            observer(id)
        }
    }

    public func applyVisibility(
        rail: Bool?,
        chat: Bool?,
        content: Bool?,
        activityBar: Bool?,
        panel: Bool?
    ) {
        if let rail { _isRailVisible = rail }
        if let chat { _isChatVisible = chat }
        if let content { _isContentVisible = content }
        if let activityBar { _isActivityBarVisible = activityBar }
        if let panel { _isPanelVisible = panel }
    }

    // MARK: - Observers

    public func addContainerObserver(_ observer: @escaping (String) -> Void) {
        observers.append(observer)
    }
}
