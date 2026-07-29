import LumiKernel
import SwiftUI

/// Conversation Context Size Plugin
///
/// 在 Chat 工具栏显示当前模型的上下文窗口大小。
@MainActor
public final class ConversationContextSizePlugin: LumiPlugin {
    public let id = "com.coffic.conversation-context-size"
    public let name = "Conversation Context Size"
    public let order = 85
    public let policy: LumiPluginPolicy = .alwaysOn

    public init() {}

    public func onBoot(kernel: LumiKernel) async throws {}

    public func onReady(kernel: LumiKernel) async throws {}

    public func chatSectionToolbarItems(kernel: LumiKernel) -> [ChatSectionToolbarItem] {
        [
            ChatSectionToolbarItem(
                id: id,
                placement: .leading
            ) {
                ConversationContextSizeToolbarView(kernel: kernel)
            }
        ]
    }
}
