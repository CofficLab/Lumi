import LumiKernel
import LumiUI

@MainActor
public final class ChatModePlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.chat-mode"
    public let name = "Chat Mode"
    public let order = 84
    public static let policy: LumiPluginPolicy = .alwaysOn

    public init() {}

    public func onReady(kernel: LumiKernel) throws {}

    public func boot(kernel: LumiKernel) async throws {}

    // MARK: - Chat Section Toolbar Bar

    public func chatSectionToolbarBarItems(kernel: LumiKernel) -> [ChatSectionToolbarBarItem] {
        [
            ChatSectionToolbarBarItem(id: id) {
                AutomationLevelToolbarView(kernel: kernel)
            }
        ]
    }
}