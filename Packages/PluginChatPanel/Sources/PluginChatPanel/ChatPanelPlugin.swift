import KernelCore
import ProviderActivityBar
import ProviderChatSection
import ProviderRailView
import ProviderRootView
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
        guard let activityBar = kernel.resolveProvider((any ActivityBarProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ActivityBarProviding from kernel")
            return
        }
        guard let chat = kernel.resolveProvider((any ChatSectionProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ChatSectionProviding from kernel")
            return
        }
        guard let rail = kernel.resolveProvider((any RailViewProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve RailViewProviding from kernel")
            return
        }
        guard let rootView = kernel.resolveProvider((any RootViewProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve RootViewProviding from kernel")
            return
        }
        let entryID = "\(id).entry"
        activityBar.addItems([ActivityBarItem(
            id: entryID,
            title: LumiPluginLocalization.string("Chat", bundle: .module),
            systemImage: "bubble.left.and.bubble.right.fill",
            order: order,
            ownerPluginID: id
        ) { activeID in
            let isChatActive = activeID == entryID
            chat.setVisible(isChatActive)
            chat.setContextActive(isChatActive)
            rootView.setContentViewHidden(isChatActive)
            if isChatActive {
                rail.activateGroup(id: self.id)
            }
        }])
        activityBar.activateItem(id: entryID)
        chat.setVisible(true)
        chat.setContextActive(true)
        rail.activateGroup(id: id)
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        let activityBar = kernel.resolveProvider((any ActivityBarProviding).self)
        let wasActive = activityBar?.activeItemID == "\(id).entry"
        activityBar?.removeItems(ids: ["\(id).entry"])
        kernel.resolveProvider((any ChatSectionProviding).self)?.setVisible(false)
        if wasActive {
            kernel.resolveProvider((any RootViewProviding).self)?.setContentViewHidden(false)
        }
    }
}
