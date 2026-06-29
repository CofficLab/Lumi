import LumiChatKit
import LumiUI
import LumiCoreKit
import SwiftUI

/// 工具栏上的会话列表入口按钮
///
/// 在窗口工具栏右上角显示一个聊天气泡图标，点击后弹出 Popover
/// 展示完整的会话列表，支持选择、删除、分页加载等操作。
public struct ConversationListPopoverButton: View {
    @StateObject private var context: ConversationListContext
    @State private var isPresented = false

    public init(
        chatService: ChatService,
        projectPathStore: (any LumiCurrentProjectPathStoring)? = nil,
        projectStore: (any LumiProjectStoring)? = nil
    ) {
        _context = StateObject(
            wrappedValue: ConversationListContext(
                chatService: chatService,
                projectPathStore: projectPathStore,
                projectStore: projectStore
            )
        )
    }

    public var body: some View {
        conversationListButton
    }

    private var conversationListButton: some View {
        AppIconButton(
            systemImage: "message.fill",
            label: LumiPluginLocalization.string("会话列表", bundle: .module)
        ) {
            isPresented.toggle()
        }
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            ConversationListView(context: context)
                .frame(width: 300, height: 480)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Conversation List Popover Button") {
    ConversationListPopoverButton(
        chatService: ConversationListPreviewSupport.makeChatService()
    )
        .padding()
        .inRootView()
}
#endif
