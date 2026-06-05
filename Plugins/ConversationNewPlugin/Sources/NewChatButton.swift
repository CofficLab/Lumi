import SwiftUI
import LumiCoreKit
import LumiUI

/// 新会话按钮视图组件
public struct NewChatButton: View {
    let creationContext: ConversationCreationContext

    public init(creationContext: ConversationCreationContext) {
        self.creationContext = creationContext
    }

    public var body: some View {
        AppIconButton(
            systemImage: "plus",
            label: String(localized: "Start New Conversation", bundle: .module)
        ) {
            Task {
                await creationContext.createConversation()
            }
        }
        .onAppear {
            creationContext.syncDefaultChatMode()
        }
    }
}
