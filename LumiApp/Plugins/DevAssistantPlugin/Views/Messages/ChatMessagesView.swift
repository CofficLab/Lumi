import SwiftUI

/// 聊天消息列表视图 - 可滚动的聊天历史记录
struct ChatMessagesView: View {
    @ObservedObject var viewModel: AssistantViewModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.messages.filter { $0.role != .system }) { msg in
                        ChatBubble(message: msg)
                            .id(msg.id)
                    }
                }
                .padding(.horizontal)
            }
            .onChange(of: viewModel.messages) { oldMessages, newMessages in
                guard let lastMessage = newMessages.last else { return }

                // 如果是新消息，则滚动并带动画
                if oldMessages.last?.id != lastMessage.id {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                } else {
                    // 如果是同一条消息（流式更新），直接滚动以减少布局闪烁
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
        }
    }
}

#Preview {
    ChatMessagesView(viewModel: AssistantViewModel())
        .padding()
        .frame(width: 800, height: 600)
        .background(Color.black)
}
