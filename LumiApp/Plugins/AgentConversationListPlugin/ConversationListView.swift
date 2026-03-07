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

    /// 是否已恢复选择标记：防止重复恢复
    @State private var hasRestoredSelection = false

    /// 是否正在处理选择变更（防止循环）
    @State private var isProcessingSelection = false

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            ConversationListHeader()

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
        .onAppear(perform: onAppear)
        .onChange(of: localSelectedConversationId, handleSelectionChange)
        .onChange(of: conversationViewModel.selectedConversationId, handleConversationSelected)
    }
}

// MARK: - View

extension ConversationListView {
}

// MARK: - Action

extension ConversationListView {
    /// 恢复上次选择的会话
    /// 仅在首次加载且没有选中的会话时执行
    private func restoreSelectionIfNeeded() {
        // 如果已经有选中的会话，不需要恢复
        if localSelectedConversationId != nil {
            if Self.verbose {
                os_log("\(self.t)已有选中的会话，跳过恢复")
            }
            return
        }

        // 调用 ConversationViewModel 的恢复方法（会验证会话是否存在）
        conversationViewModel.restoreSelectedConversation(modelContext: modelContext)

        // 同步到本地选择状态（使用 isProcessingSelection 防止触发 onChange 循环）
        if conversationViewModel.selectedConversationId != nil {
            isProcessingSelection = true
            localSelectedConversationId = conversationViewModel.selectedConversationId
            os_log("\(self.t)✅ 已恢复上次选择的会话: \(self.localSelectedConversationId?.uuidString ?? "nil")")

            // 延迟重置标志
            DispatchQueue.main.async {
                isProcessingSelection = false
            }
        } else {
            if Self.verbose {
                os_log("\(self.t)ℹ️ 没有保存的会话选择")
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
        // 首次加载时恢复上次选择的会话
        if !hasRestoredSelection && !conversations.isEmpty {
            hasRestoredSelection = true
            Task { @MainActor in
                restoreSelectionIfNeeded()
            }
        }
    }

    /// 处理选择变化：同步到 ConversationViewModel
    func handleSelectionChange() {
        let localId = localSelectedConversationId?.uuidString ?? "nil"
        let vmId = conversationViewModel.selectedConversationId?.uuidString ?? "nil"
        os_log("\(self.t)🔄 handleSelectionChange called: local=\(localId), vm=\(vmId)")

        // 如果正在处理选择变更，跳过（防止循环）
        guard !isProcessingSelection else {
            os_log("\(self.t)⏭️ 正在处理中，跳过")
            return
        }

        // 只在值确实不同时才更新，避免循环
        guard localSelectedConversationId != conversationViewModel.selectedConversationId else {
            os_log("\(self.t)⏭️ 值相同，跳过处理")
            return
        }

        isProcessingSelection = true

        // 使用 async 延迟执行，打破同步循环
        DispatchQueue.main.async {
            if let newId = self.localSelectedConversationId {
                os_log("\(self.t)👉 从 List 选择会话: \(newId)")
                self.conversationViewModel.selectConversation(newId)
            } else {
                os_log("\(self.t)👉 清除会话选择")
                self.conversationViewModel.clearConversationSelection()
            }

            // 延迟重置标志
            DispatchQueue.main.async {
                self.isProcessingSelection = false
            }
        }
    }

    func handleConversationSelected() {
        let localId = localSelectedConversationId?.uuidString ?? "nil"
        let vmId = conversationViewModel.selectedConversationId?.uuidString ?? "nil"
        os_log("\(self.t)🔄 handleConversationSelected called: local=\(localId), vm=\(vmId)")

        // 如果正在处理选择变更，跳过（防止循环）
        guard !isProcessingSelection else {
            os_log("\(self.t)⏭️ 正在处理中，跳过")
            return
        }

        // 只在值确实不同时才更新，避免循环
        guard localSelectedConversationId != conversationViewModel.selectedConversationId else {
            os_log("\(self.t)⏭️ 值相同，跳过处理")
            return
        }

        isProcessingSelection = true

        // 使用 async 延迟执行，打破同步循环
        DispatchQueue.main.async {
            if let conversationId = self.conversationViewModel.selectedConversationId {
                if self.conversations.first(where: { $0.id == conversationId }) != nil {
                    os_log("\(self.t)👉 同步 VM 选择到 List: \(conversationId)")
                    self.localSelectedConversationId = conversationId
                }
            }

            // 延迟重置标志
            DispatchQueue.main.async {
                self.isProcessingSelection = false
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
