import KernelCore
import ProviderActivityBar
import ProviderChatSection
import ProviderContentView

@MainActor
public final class ChatPanelPlugin: SuperPlugin {
    public let id = "com.coffic.lumi.plugin.chat-panel"
    // Chat is the default workbench, matching the legacy app's initial state.
    public let order = 1
    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        let activityBar = kernel.resolveProvider((any ActivityBarProviding).self)
        let chat = kernel.resolveProvider((any ChatSectionProviding).self)
        let content = kernel.resolveProvider((any ContentViewProviding).self)
        let entryID = "\(id).entry"
        activityBar?.addItems([ActivityBarItem(
            id: entryID,
            title: "Chat",
            systemImage: "bubble.left.and.bubble.right.fill",
            order: order
        ) { activeID in
            let isChatActive = activeID == entryID
            chat?.setVisible(isChatActive)
            chat?.setContextActive(isChatActive)
            if isChatActive {
                content?.setContentView(chat?.makeChatSectionView())
            }
        }])
        // Adding a late plugin must still select Chat on first launch; the
        // legacy app opens directly into the conversation workbench.
        activityBar?.activateItem(id: entryID)
        chat?.setVisible(true)
        chat?.setContextActive(true)
        content?.setContentView(chat?.makeChatSectionView())
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ActivityBarProviding).self)?.removeItems(ids: ["\(id).entry"])
        kernel.resolveProvider((any ChatSectionProviding).self)?.setVisible(false)
    }
}
