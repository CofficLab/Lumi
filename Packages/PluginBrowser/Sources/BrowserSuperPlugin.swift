import KernelCore
import ProviderActivityBar
import ProviderChatSection
import ProviderContentView
import ProviderConversation
import ProviderRootView
import ProviderToolManager
import ProviderToolbar
import KitSuperLog
import os
import SwiftUI
#if os(macOS)
import KitMCP
import ProviderMCP
#endif

@MainActor
public final class BrowserSuperPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.browser", category: "Browser")
    public let id = "Browser"
    public let order = 102
    public let metadata = PluginMetadata(
        id: "Browser",
        name: "Browser",
        description: "Control web browser for viewing and interacting with web pages.",
        category: .integration,
        stage: .preview,
        policy: .alwaysOn
    )

    public init() {}

    private var sessions: BrowserSessionManager?
    private weak var activityBar: (any ActivityBarProviding)?
    private weak var contentView: (any ContentViewProviding)?
    private weak var chat: (any ChatSectionProviding)?
    private weak var rootView: (any RootViewProviding)?
    private weak var toolbar: (any ToolbarProviding)?
    private var selectedConversationObserver: (any SelectedConversationObserverHandle)?
    private let entryID = "Browser.entry"

    public func onBoot(kernel: KernelCoreContainer) throws {
        let sessions = BrowserSessionManager()
        self.sessions = sessions
        activityBar = kernel.resolveProvider((any ActivityBarProviding).self)
        contentView = kernel.resolveProvider((any ContentViewProviding).self)
        chat = kernel.resolveProvider((any ChatSectionProviding).self)
        rootView = kernel.resolveProvider((any RootViewProviding).self)
        toolbar = kernel.resolveProvider((any ToolbarProviding).self)

        if let conversations = kernel.resolveProvider((any ConversationManaging).self) {
            sessions.selectConversation(conversations.selectedConversationID)
            selectedConversationObserver = conversations.addSelectedConversationObserver { [weak sessions] conversationID in
                sessions?.selectConversation(conversationID)
            }
        }

        sessions.onRequestPresentation = { [weak self] in
            self?.activityBar?.activateItem(id: self?.entryID)
        }

        let view = AnyView(BrowserWorkspaceView(manager: sessions))
        activityBar?.addItems([
            ActivityBarItem(
                id: entryID,
                title: metadata.name,
                systemImage: "globe",
                order: order,
                ownerPluginID: id
            ) { [weak self] state in
                self?.setActive(state == .activated, view: view)
            },
        ])
        if activityBar == nil {
            contentView?.setContentView(view)
        }

        let toolManager = kernel.resolveProvider((any ToolManagerProviding).self)
        toolManager?.add(BrowserOpenTool(sessions: sessions), pluginID: id)
        toolManager?.add(BrowserReadTool(sessions: sessions), pluginID: id)
        toolManager?.add(BrowserInteractTool(sessions: sessions), pluginID: id)
    }

    /// Register Chrome DevTools after every plugin has completed booting, so
    /// PluginMCP has already published its server contribution provider.
    public func onReady(kernel: KernelCoreContainer) throws {
        #if os(macOS)
        guard let contributor = kernel.resolveProvider((any MCPServerContributionProviding).self) else {
            Self.logger.error("MCP server contribution provider is unavailable; Chrome DevTools was not registered.")
            return
        }
        contributor.contribute(
            MCPServerConfig(
                name: "Chrome DevTools (official)",
                command: "npx",
                arguments: ["-y", "chrome-devtools-mcp@latest"]
            )
        )
        #endif
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        selectedConversationObserver?.cancel()
        selectedConversationObserver = nil
        let wasActive = activityBar?.activeItemID == entryID
        activityBar?.removeItems(ids: [entryID])
        kernel.resolveProvider((any ToolManagerProviding).self)?.remove(id: "browser_open")
        kernel.resolveProvider((any ToolManagerProviding).self)?.remove(id: "browser_read")
        kernel.resolveProvider((any ToolManagerProviding).self)?.remove(id: "browser_interact")
        if wasActive {
            contentView?.setContentView(nil)
            rootView?.setContentViewHidden(false)
            rootView?.setContentHeaderViewHidden(false)
            chat?.setVisible(true)
            chat?.setContextActive(true)
            chat?.setActiveContext(.defaultChat)
            toolbar?.setVisibleCategories(Set(ToolbarItemCategory.allCases))
        }
        sessions?.onRequestPresentation = nil
        sessions = nil
    }

    private func setActive(_ active: Bool, view: AnyView) {
        if active {
            toolbar?.setVisibleCategories([.global, .chat, .project])
            rootView?.setContentHeaderViewHidden(true)
            rootView?.setContentViewHidden(false)
            contentView?.setContentView(view)
            chat?.setVisible(true)
            chat?.setContextActive(true)
            chat?.setActiveContext(.defaultChat)
        } else {
            contentView?.setContentView(nil)
            rootView?.setContentViewHidden(false)
            rootView?.setContentHeaderViewHidden(false)
            chat?.setVisible(false)
            chat?.setContextActive(false)
            chat?.setActiveContext(nil)
            toolbar?.setVisibleCategories(Set(ToolbarItemCategory.allCases))
        }
    }
}
