import LumiCoreChat
import LumiKernel
import LumiUI
import SwiftUI

/// Conversation Input Plugin
///
/// 向 Chat 区域底部添加一个输入框（仅 UI 展示，尚未接入发送逻辑）。
@MainActor
public final class ConversationInputPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.conversation-input"
    public let name = "Conversation Input"
    public let order = 83
    public static let policy: LumiPluginPolicy = .optOut

    public init() {}

    public func register(kernel: LumiKernel) throws {}

    public func boot(kernel: LumiKernel) async throws {}

    public func chatSectionItems(kernel: LumiKernel) -> [ChatSectionItem] {
        [
            ChatSectionItem(
                id: id,
                placement: .bottomFixed,
                fillsRemainingHeight: false,
                showsTrailingDivider: false
            ) {
                ConversationInputView()
            }
        ]
    }
}