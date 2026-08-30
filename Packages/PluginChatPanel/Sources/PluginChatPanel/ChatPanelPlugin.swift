import KernelCore
import ProviderActivityBar
import ProviderChatSection
import ProviderRootView
import ProviderRailView
import ProviderStorage
import ProviderToolbar
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
        guard let rootView = kernel.resolveProvider((any RootViewProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve RootViewProviding from kernel")
            return
        }
        let railView = kernel.resolveProvider((any RailViewProviding).self)
        let toolbar = kernel.resolveProvider((any ToolbarProviding).self)
        let entryID = "\(id).entry"
        let pluginID = id
        let railWidthStore = kernel
            .resolveProvider((any StorageProviding).self)
            .map { storage in
                FileRailViewWidthStore(
                    fileURL: storage
                        .pluginDataDirectory(for: pluginID)
                        .appendingPathComponent("rail-view-width.plist", isDirectory: false)
                )
            }
        let chatWidthStore = kernel
            .resolveProvider((any StorageProviding).self)
            .map { storage in
                FileChatSectionWidthStore(
                    fileURL: storage
                        .pluginDataDirectory(for: pluginID)
                        .appendingPathComponent("chat-section-width.plist", isDirectory: false)
                )
            }
        
        activityBar.addItems([ActivityBarItem(
            id: entryID,
            title: LumiPluginLocalization.string("Chat", bundle: .module),
            systemImage: "bubble.left.and.bubble.right.fill",
            order: order,
            ownerPluginID: id
        ) { state in
            let isChatActive = state == .activated
            toolbar?.setVisibleCategories(isChatActive ? [.global, .chat, .project] : Set(ToolbarItemCategory.allCases))
            chat.setVisible(isChatActive)
            chat.setContextActive(isChatActive)
            chat.setActiveContext(isChatActive ? .defaultChat : nil)
            if isChatActive {
                chat.activateWidthProfile(
                    ownerID: pluginID,
                    recommended: .standard,
                    store: chatWidthStore
                )
                railView?.activateWidthProfile(
                    ownerID: pluginID,
                    recommended: .standard,
                    store: railWidthStore
                )
            } else {
                chat.deactivateWidthProfile(ownerID: pluginID)
                railView?.deactivateWidthProfile(ownerID: pluginID)
            }
            rootView.setContentViewHidden(isChatActive)
            rootView.setContentHeaderViewHidden(!isChatActive)
            railView?.setVisibleCategories(isChatActive ? [.chat, .fileTree] : Set(RailViewCategory.allCases))
        }])
        
        activityBar.activateItem(id: entryID)
        chat.setVisible(true)
        chat.setContextActive(true)
        chat.setActiveContext(.defaultChat)
        chat.activateWidthProfile(
            ownerID: id,
            recommended: .standard,
            store: chatWidthStore
        )
        railView?.activateWidthProfile(
            ownerID: id,
            recommended: .standard,
            store: railWidthStore
        )
        rootView.setContentHeaderViewHidden(true)
        railView?.setVisibleCategories([.chat, .fileTree])
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        let activityBar = kernel.resolveProvider((any ActivityBarProviding).self)
        let wasActive = activityBar?.activeItemID == "\(id).entry"
        activityBar?.removeItems(ids: ["\(id).entry"])
        kernel.resolveProvider((any ChatSectionProviding).self)?.setVisible(false)
        if wasActive {
            kernel.resolveProvider((any ChatSectionProviding).self)?.deactivateWidthProfile(ownerID: id)
            kernel.resolveProvider((any RailViewProviding).self)?.deactivateWidthProfile(ownerID: id)
            kernel.resolveProvider((any RootViewProviding).self)?.setContentViewHidden(false)
            kernel.resolveProvider((any RootViewProviding).self)?.setContentHeaderViewHidden(false)
            kernel.resolveProvider((any RailViewProviding).self)?.setVisibleCategories(Set(RailViewCategory.allCases))
        }
    }
}
