import KernelCore
import ProviderActivityBar
import ProviderChatSection
import ProviderRootView
import ProviderRailView
import ProviderStorage
import ProviderToolbar
import KitSuperLog
import os

/// Persists the last active Rail tab ID for the Chat panel.
///
/// Storage: a single key `"activeTabID"` in a binary plist file
/// inside the plugin's data directory.
@MainActor
final class FileRailActiveTabStore {
    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func load() -> String? {
        guard let data = try? Data(contentsOf: fileURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = plist as? [String: String],
              let tabID = dict["activeTabID"], !tabID.isEmpty else {
            return nil
        }
        return tabID
    }

    func save(_ tabID: String) {
        guard !tabID.isEmpty else { return }
        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try PropertyListSerialization.data(
                fromPropertyList: ["activeTabID": tabID],
                format: .binary,
                options: 0
            )
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Silently ignore persistence failures.
        }
    }
}

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
    private var railObserverHandle: (any RailViewProvidingObserverHandle)?
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
        let activeTabStore = kernel
            .resolveProvider((any StorageProviding).self)
            .map { storage in
                FileRailActiveTabStore(
                    fileURL: storage
                        .pluginDataDirectory(for: pluginID)
                        .appendingPathComponent("rail-active-tab.plist", isDirectory: false)
                )
            }

        // Track whether Chat is the active panel so the observer only
        // persists tab changes that happen while Chat owns the Rail.
        final class ChatActiveState { var isActive = true }
        let chatActiveState = ChatActiveState()

        railObserverHandle = railView?.addObserver { [weak self] event in
            guard case .activeTabChanged(let tabID) = event,
                  let tabID,
                  chatActiveState.isActive else { return }
            activeTabStore?.save(tabID)
            _ = self // prevent premature deallocation warning
        }

        activityBar.addItems([ActivityBarItem(
            id: entryID,
            title: LumiPluginLocalization.string("Chat", bundle: .module),
            systemImage: "bubble.left.and.bubble.right.fill",
            order: order,
            ownerPluginID: id
        ) { state in
            let isChatActive = state == .activated
            chatActiveState.isActive = isChatActive
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
            // Restore the last active tab when Chat becomes active.
            if isChatActive, let savedTabID = activeTabStore?.load() {
                railView?.activateTab(id: savedTabID)
            }
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
        // Restore the last active tab on initial boot.
        if let savedTabID = activeTabStore?.load() {
            railView?.activateTab(id: savedTabID)
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        railObserverHandle?.cancel()
        railObserverHandle = nil
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
