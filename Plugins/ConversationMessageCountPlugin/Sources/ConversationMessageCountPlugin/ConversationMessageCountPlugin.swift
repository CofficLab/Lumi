import LumiKernel
import LumiKernel
import LumiUI
import SwiftUI

/// Conversation Message Count Plugin
///
/// 在 chat 工具栏上显示当前对话的消息数量。
@MainActor
public final class ConversationMessageCountPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.conversation-message-count"
    public let name = "Conversation Message Count"
    public let order = 84
    public static let policy: LumiPluginPolicy = .optOut

    public init() {}

    public func onReady(kernel: LumiKernel) throws {}

    public func boot(kernel: LumiKernel) async throws {}

    public func chatSectionToolbarItems(kernel: LumiKernel) -> [ChatSectionToolbarItem] {
        [
            ChatSectionToolbarItem(
                id: id,
                placement: .leading
            ) {
                MessageCountToolbarView(kernel: kernel)
            }
        ]
    }
}