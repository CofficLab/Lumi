import SwiftUI
import LumiUI

/// 新会话按钮视图组件
public struct NewChatButton: View {
    public init() {}

    public var body: some View {
        AppIconButton(
            systemImage: "plus",
            label: String(localized: "Start New Conversation", table: "ConversationNew")
        ) {
            Task {
                await ConversationNewRuntime.createConversation()
            }
        }
    }
}
