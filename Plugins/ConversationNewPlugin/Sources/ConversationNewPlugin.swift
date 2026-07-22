import LumiKernel
import LumiUI
import SwiftUI

@MainActor
public final class ConversationNewPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.conversation-new"
    public let name = "New Chat Button"
    public let order = 60
    public static let policy: LumiPluginPolicy = .alwaysOn

    public init() {}

    public func onReady(kernel: LumiKernel) throws {
        let toolbarItem = TitleToolbarItem(
            id: "\(id).new-chat",
            title: "New Chat",
            placement: .trailing
        ) {
            NewChatButton(kernel: kernel)
        }
        kernel.toolbarProvider?.registerTitleToolbarItem(toolbarItem)
    }

    public func boot(kernel: LumiKernel) async throws {}
}
