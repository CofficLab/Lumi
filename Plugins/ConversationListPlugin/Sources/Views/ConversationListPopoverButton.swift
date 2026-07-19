import LumiKernel
import LumiUI
import LumiKernel
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
        projectPathStore: ProjectComponent? = nil,
        projectStore: ProjectComponent? = nil
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
        ZStack(alignment: .topTrailing) {
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

            if context.unreadCount > 0 {
                unreadBadge
                    .offset(x: 4, y: -4)
            }
        }
    }

    @ViewBuilder
    private var unreadBadge: some View {
        let count = min(context.unreadCount, 99)
        let text = count > 99 ? "99+" : "\(count)"

        Text(text)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundColor(Color.white)
            .frame(minWidth: 18, minHeight: 18)
            .padding(.horizontal, count >= 10 ? 5 : 4)
            .background(
                Capsule()
                    .fill(Color.red)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
            )
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
