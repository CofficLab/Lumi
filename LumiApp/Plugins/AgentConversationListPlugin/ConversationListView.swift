import MagicKit
import OSLog
import SwiftData
import SwiftUI

/// 对话列表视图
/// 使用 List 渲染会话列表，支持会话选择、删除和自动恢复上次选择的会话
struct ConversationListView: View, SuperLog {
    /// 日志标识 emoji
    nonisolated static let emoji = "🐶"
    /// 是否输出详细日志
    nonisolated static let verbose = true

    /// 数据上下文：用于查询和删除会话
    @Environment(\.modelContext) private var modelContext
    /// 会话管理 ViewModel
    @EnvironmentObject var conversationViewModel: ConversationViewModel

    /// 会话列表：按更新时间倒序排列
    @Query(sort: \Conversation.updatedAt, order: .reverse)
    private var conversations: [Conversation]

    /// 本地选择的会话 ID
    @State private var localSelectedConversationId: UUID?

    /// 折叠状态
    @State private var isExpanded: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            ConversationListHeader(isExpanded: $isExpanded)

            if isExpanded {
                Divider()
                    .background(Color.white.opacity(0.1))

                // 对话列表内容
                if conversations.isEmpty {
                    ConversationListEmptyView()
                } else {
                    List(conversations, selection: $localSelectedConversationId) { conversation in
                        ConversationItemView(
                            conversation: conversation,
                            onDelete: { handleDelete(conversation) }
                        )
                        .tag(conversation.id)
                    }
                }
            }
        }
        .onAppear(perform: onAppear)
        .onChange(of: localSelectedConversationId, handleLocalSelectionChange)
        .onChange(of: conversationViewModel.selectedConversationId, handleConversationSelected)
        .onChange(of: conversations) { _, newConversations in
            // 当会话列表变化时，同步当前选中的会话
            handleConversationsChanged(newConversations)
        }
    }
}

// MARK: - View

extension ConversationListView {
}

// MARK: - Action

extension ConversationListView {
    /// 同步 VM 的选中状态到本地 List
    /// 在视图出现时调用，确保 List 的选中状态与 VM 一致
    private func syncSelectionFromViewModel() {
        let vmId = conversationViewModel.selectedConversationId

        // 如果 VM 有选中的会话，同步到本地
        if let selectedId = vmId {
            // 检查选中的会话是否存在于当前列表中
            if conversations.first(where: { $0.id == selectedId }) != nil {
                if localSelectedConversationId != selectedId {
                    localSelectedConversationId = selectedId
                    os_log("\(self.t)✅ [\(selectedId)] 同步 VM 选中状态到 List")
                }
            } else {
                // 选中的会话不存在于列表中，清除选择
                os_log("\(self.t)⚠️ 选中的会话不存在于列表中")
                localSelectedConversationId = nil
            }
        } else {
            // VM 没有选中会话，清除本地选择
            if localSelectedConversationId != nil {
                localSelectedConversationId = nil
            }
        }
    }

    /// 处理删除会话操作
    /// 删除后如果当前选中的是被删除的会话，自动切换到最新的会话
    /// - Parameter conversation: 要删除的会话
    private func handleDelete(_ conversation: Conversation) {
        if Self.verbose {
            os_log("\(self.t)🗑️ 开始删除对话：\(conversation.title)")
        }

        // 如果删除的是当前选中的会话，且还有其他会话，自动切换到最新的
        if localSelectedConversationId == conversation.id {
            let remainingConversations = conversations.filter { $0.id != conversation.id }
            if let nextConversation = remainingConversations.first {
                localSelectedConversationId = nextConversation.id
                if Self.verbose {
                    os_log("\(self.t)🔄 已自动切换到对话：\(nextConversation.title)")
                }
            } else {
                localSelectedConversationId = nil
            }
        }

        // 使用当前视图的 modelContext 删除，确保 @Query 能检测到变化
        modelContext.delete(conversation)

        do {
            try modelContext.save()
        } catch {
            os_log(.error, "\(self.t)❌ 删除对话失败：\(error.localizedDescription)")
        }
    }
}

// MARK: - Setter

extension ConversationListView {
}

// MARK: - Event Handler

extension ConversationListView {
    /// 视图出现时的事件处理
    func onAppear() {
        // 同步 VM 的选中状态到本地 List
        // 注意：不再恢复上次的选择，而是在 RootView 初始化时恢复
        if !conversations.isEmpty {
            syncSelectionFromViewModel()
        }
    }

    /// 处理会话列表变化
    func handleConversationsChanged(_ newConversations: [Conversation]) {
        // 如果当前选中的会话不在新列表中，清除选择
        if let localId = localSelectedConversationId {
            if !newConversations.contains(where: { $0.id == localId }) {
                os_log("\(self.t)⚠️ 当前选中的会话已不在列表中，清除选择")
                localSelectedConversationId = nil
            }
        }
    }

    /// 处理选择变化：同步到 ConversationViewModel
    func handleLocalSelectionChange() {
        let localId = localSelectedConversationId?.uuidString ?? "nil"
        let vmId = conversationViewModel.selectedConversationId?.uuidString ?? "nil"

        // 只在值确实不同时才更新，避免循环
        guard localSelectedConversationId != conversationViewModel.selectedConversationId else {
            return
        }

        if let newId = self.localSelectedConversationId {
            if Self.verbose {
                os_log("\(self.t)👉 [\(newId)] 从 List 选择会话")
            }
            self.conversationViewModel.setSelectedConversation(newId)
        } else {
            if Self.verbose {
                os_log("\(self.t)👉 清除会话选择")
            }
            self.conversationViewModel.setSelectedConversation(nil)
        }
    }

    func handleConversationSelected() {
        let localId = localSelectedConversationId?.uuidString ?? "nil"
        let vmId = conversationViewModel.selectedConversationId?.uuidString ?? "nil"
        os_log("\(self.t)🔄 handleConversationSelected called: local=\(localId), vm=\(vmId)")

        // 只在值确实不同时才更新，避免循环
        guard localSelectedConversationId != conversationViewModel.selectedConversationId else {
            return
        }

        if let conversationId = self.conversationViewModel.selectedConversationId {
            if self.conversations.first(where: { $0.id == conversationId }) != nil {
                os_log("\(self.t)👉 同步 VM 选择到 List: \(conversationId)")
                self.localSelectedConversationId = conversationId
            }
        }
    }
}

// MARK: - Preview

#Preview("对话列表 - 标准尺寸") {
    ConversationListView()
        .frame(width: 300, height: 600)
}

#Preview("对话列表 - 窄屏") {
    ConversationListView()
        .frame(width: 250, height: 400)
}
