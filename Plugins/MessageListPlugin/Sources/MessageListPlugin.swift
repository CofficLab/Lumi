import LumiKernel

/// Message List Plugin
///
/// Provides the chat message list view in the ChatSection.
@MainActor
public final class MessageListPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.message-list"
    public let name = "Message List"
    public let order = 82

    public init() {}

    public func register(kernel: LumiKernel) throws {}

    public func boot(kernel: LumiKernel) async throws {}

    // MARK: - Chat Section Items

    public func chatSectionItems(kernel: LumiKernel) -> [ChatSectionItem] {
        [
            ChatSectionItem(
                id: id,
                placement: .stack,
                fillsRemainingHeight: true
            ) {
                MessageListView(kernel: kernel)
            }
        ]
    }
}
