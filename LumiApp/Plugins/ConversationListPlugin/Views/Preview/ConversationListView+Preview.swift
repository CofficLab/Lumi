import SwiftUI
import MagicKit
import SwiftData

// MARK: - ConversationListView Preview

#Preview("会话列表") {
    ConversationListView()
        .frame(width: 220, height: 400)
        .modelContainer(for: [Conversation.self, ChatMessageEntity.self])
        .inRootView()
}

// MARK: - ConversationListHeader Preview

#Preview("列表头部") {
    ConversationListHeader()
        .frame(width: 220)
}

// MARK: - ConversationListEmptyView Preview

#Preview("空状态") {
    ConversationListEmptyView()
        .frame(width: 220, height: 100)
}

// MARK: - ConversationItemView Preview

#Preview("会话项 - 未选中") {
    let conversation = Conversation(
        projectId: "/Users/test/project",
        title: "如何实现数据绑定",
        createdAt: Date().addingTimeInterval(-3600),
        updatedAt: Date().addingTimeInterval(-60)
    )
    
    return ConversationItemView(conversation: conversation, onDelete: { _ in })
        .frame(width: 220)
        .padding()
        .modelContainer(for: [Conversation.self, ChatMessageEntity.self])
        .inRootView()
}

#Preview("会话项 - 选中") {
    let conversation = Conversation(
        projectId: "/Users/test/project",
        title: "如何实现数据绑定",
        createdAt: Date().addingTimeInterval(-3600),
        updatedAt: Date().addingTimeInterval(-60)
    )
    
    // 模拟选中状态
    AgentProvider.shared.selectedConversationId = conversation.id
    
    return ConversationItemView(conversation: conversation, onDelete: { _ in })
        .frame(width: 220)
        .padding()
        .modelContainer(for: [Conversation.self, ChatMessageEntity.self])
        .inRootView()
}
