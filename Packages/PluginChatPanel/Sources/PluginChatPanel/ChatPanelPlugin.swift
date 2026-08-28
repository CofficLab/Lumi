import KernelCore
import ProviderActivityBar
import ProviderChatSection
import ProviderContentView
import ProviderRailView
import ProviderWorkspace
import KitSuperLog
import os

@MainActor
public final class ChatPanelPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.chat-panel", category: "ChatPanel")
    public let id = "com.coffic.lumi.plugin.chat-panel"
    // Chat is the default workbench, matching the legacy app's initial state.
    public let order = 1
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.chat-panel",
        name: "Chat Panel",
        description: "",
        category: .chat,
        stage: .stable,
        policy: .alwaysOn
    )
    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        let activityBar = kernel.resolveProvider((any ActivityBarProviding).self)
        let chat = kernel.resolveProvider((any ChatSectionProviding).self)
        let rail = kernel.resolveProvider((any RailViewProviding).self)
        let workspace = kernel.resolveProvider((any WorkspaceProviding).self)
        let contentView = kernel.resolveProvider((any ContentViewProviding).self)
        let entryID = "\(id).entry"
        workspace?.registerContainer(.init(
            id: id,
            title: LumiPluginLocalization.string("Chat", bundle: .module),
            systemImage: "bubble.left.and.bubble.right.fill",
            order: order,
            supportsProject: true,
            railVisibility: .visibleByDefault,
            chatVisibility: .alwaysVisible,
            panelHeaderVisibility: .unsupported,
            panelBodyVisibility: .unsupported,
            panelBottomVisibility: .unsupported
        ), ownerPluginID: id)
        activityBar?.addItems([ActivityBarItem(
            id: entryID,
            title: LumiPluginLocalization.string("Chat", bundle: .module),
            systemImage: "bubble.left.and.bubble.right.fill",
            order: order,
            ownerPluginID: id
        ) { activeID in
            let isChatActive = activeID == entryID
            chat?.setVisible(isChatActive)
            chat?.setContextActive(isChatActive)
            rail?.activateGroup(id: isChatActive ? self.id : nil)
            if isChatActive {
                workspace?.activateContainer(id: self.id)
                // Chat 容器自带聊天界面，不需要独立的主内容区：
                // 激活时清空 contentView，回退到占位视图。
                contentView?.setContentView(nil)
            }
        }])
        // Adding a late plugin must still select Chat on first launch; the
        // legacy app opens directly into the conversation workbench.
        activityBar?.activateItem(id: entryID)
        chat?.setVisible(true)
        chat?.setContextActive(true)
        rail?.activateGroup(id: id)
        workspace?.activateContainer(id: id)
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ActivityBarProviding).self)?.removeItems(ids: ["\(id).entry"])
        kernel.resolveProvider((any ChatSectionProviding).self)?.setVisible(false)
        kernel.resolveProvider((any WorkspaceProviding).self)?.unregisterContainers(ownerPluginID: id)
    }
}
