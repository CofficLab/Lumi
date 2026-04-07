import Combine
import MagicKit
import SwiftUI

/// 对话列表视图
/// 使用分页方式渲染会话列表，避免一次性加载全部历史记录
struct ConversationListView: View, SuperLog {
    /// 日志标识 emoji
    nonisolated static let emoji = "🐶"
    /// 是否输出详细日志
    nonisolated static let verbose = false

    /// 会话管理 ViewModel
    @EnvironmentObject var conversationVM: ConversationVM
    
    /// 项目管理 ViewModel
    @EnvironmentObject var projectVM: ProjectVM
    
    private let selectionStore = ConversationListLocalStore.shared

    /// 当前页已加载的会话
    @State private var conversations: [Conversation] = []

    /// 本地选择的会话 ID
    @State private var localSelectedConversationId: UUID?

    /// 分页状态
    @State private var nextOffset: Int = 0
    @State private var hasMore: Bool = true
    @State private var isLoadingPage: Bool = false
    @State private var didInitialLoad: Bool = false
    @State private var didRestoreSelection: Bool = false
    @State private var lastReloadSelectionId: UUID?

    /// 每页大小
    private let pageSize: Int = 40

    private let listTopAnchorId = "conversation_list_top_anchor"

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                // 对话列表内容
                if conversations.isEmpty {
                    if isLoadingPage {
                        loadingView
                    } else {
                        ConversationListEmptyView()
                    }
                } else {
                    conversationListContent(proxy: proxy)
                }
            }
            .onAppear(perform: performInitialLoadIfNeeded)
            .onChange(of: localSelectedConversationId, handleLocalSelectionChange)
            .onChange(of: conversationVM.selectedConversationId, handleConversationSelected)
            .onChange(of: conversationVM.selectedConversationId) { _, newValue in
                selectionStore.saveSelectedConversationId(newValue)
            }
            .onChange(of: conversations) { _, newConversations in
                // 当会话列表变化时，同步当前选中的会话
                handleConversationsChanged(newConversations)
            }
            .onReceive(NotificationCenter.default.publisher(for: .conversationDidChange)) { notification in
                handleConversationDidChangeNotification(notification)
            }
            .onAgentConversationCreated { conversationId in
                handleAgentConversationCreated(conversationId: conversationId, proxy: proxy)
            }
        }
    }
}

// MARK: - View

extension ConversationListView {
    private var loadingView: some View {
        ProgressView(String(localized: "Loading...", table: "ConversationList"))
            .font(.system(size: 11))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.vertical, 12)
    }

    private func conversationListContent(proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 0) {
            List(selection: $localSelectedConversationId) {
                Color.clear
                    .frame(height: 0)
                    .id(listTopAnchorId)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowSeparator(.hidden)

                ForEach(conversations, id: \.id) { conversation in
                    ConversationItemView(
                        conversation: conversation,
                        onDelete: { handleDelete(conversation) }
                    )
                    .id(conversation.id)
                    .tag(conversation.id)
                    .onAppear {
                        handleRowAppear(conversation)
                    }
                }
            }
            .listStyle(.plain)
            .environment(\.defaultMinListRowHeight, 0)

            if isLoadingPage {
                loadingIndicator
            }
        }
    }

    private var loadingIndicator: some View {
        HStack {
            Spacer()
            ProgressView()
                .controlSize(.small)
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Action

extension ConversationListView {
    /// 同步 VM 的选中状态到本地 List
    /// 在分页加载后调用，确保 List 的选中状态与 VM 一致
    private func syncSelectionFromViewModel() {
        let vmId = conversationVM.selectedConversationId

        // 如果 VM 有选中的会话，同步到本地
        if let selectedId = vmId {
            // 检查选中的会话是否存在于当前列表中
            if conversations.first(where: { $0.id == selectedId }) != nil {
                if localSelectedConversationId != selectedId {
                    localSelectedConversationId = selectedId
                }
            } else {
                // 选中的会话不存在于列表中，清除选择
                ConversationListPlugin.logger.info("\(self.t)⚠️ [\(selectedId)] 选中的会话不存在于列表中")
                localSelectedConversationId = nil
            }
        } else {
            // VM 没有选中会话，清除本地选择
            if localSelectedConversationId != nil {
                localSelectedConversationId = nil
            }
        }
    }

    /// 删除会话，并同步分页列表状态
    /// - Parameter conversation: 要删除的会话
    private func handleDelete(_ conversation: Conversation) {
        if Self.verbose {
            ConversationListPlugin.logger.info("\(self.t)🗑️ 开始删除对话：\(conversation.title)")
        }

        // 如果删除的是当前选中的会话，且还有其他会话，自动切换到最新的
        if localSelectedConversationId == conversation.id {
            let remainingConversations = conversations.filter { $0.id != conversation.id }
            if let nextConversation = remainingConversations.first {
                localSelectedConversationId = nextConversation.id
                if Self.verbose {
                    ConversationListPlugin.logger.info("\(self.t)🔄 已自动切换到对话：\(nextConversation.title)")
                }
            } else {
                localSelectedConversationId = nil
            }
        }

        // 从本地分页列表中移除，保持 UI 即时响应
        conversations.removeAll { $0.id == conversation.id }
        nextOffset = max(0, nextOffset - 1)
        if conversations.count < pageSize {
            hasMore = true
        }

        conversationVM.deleteConversation(conversation)
    }

    /// 视图首次出现时加载第一页
    private func performInitialLoadIfNeeded() {
        restoreSelectionFromPluginStoreIfNeeded()

        guard !didInitialLoad else {
            syncSelectionFromViewModel()
            return
        }

        didInitialLoad = true
        reloadFromFirstPage()
    }

    /// 从第一页重新加载
    private func reloadFromFirstPage() {
        conversations = []
        nextOffset = 0
        hasMore = true
        loadNextPageIfNeeded()
    }

    private func restoreSelectionFromPluginStoreIfNeeded() {
        guard !didRestoreSelection else { return }
        didRestoreSelection = true

        guard let storedId = selectionStore.loadSelectedConversationId(),
              let conversation = conversationVM.fetchConversation(id: storedId) else {
            return
        }

        conversationVM.setSelectedConversation(storedId)
        
        // 恢复会话选择时，也切换到关联的项目
        switchToProjectIfNeeded(for: conversation)
        
        if Self.verbose {
            ConversationListPlugin.logger.info("\(self.t)✅ [\(storedId)] 从插件存储恢复会话选择")
        }
    }

    /// 滚动到末尾时触发续页
    private func handleRowAppear(_ conversation: Conversation) {
        guard conversation.id == conversations.last?.id else { return }
        loadNextPageIfNeeded()
    }

    /// 分页加载下一页
    private func loadNextPageIfNeeded() {
        guard hasMore, !isLoadingPage else { return }

        isLoadingPage = true
        let page = conversationVM.fetchConversationsPage(limit: pageSize, offset: nextOffset)

        if nextOffset == 0 {
            conversations = page
        } else {
            let existingIds = Set(conversations.map(\.id))
            conversations.append(contentsOf: page.filter { !existingIds.contains($0.id) })
        }

        nextOffset += page.count
        hasMore = page.count == pageSize
        isLoadingPage = false

        syncSelectionFromViewModel()
    }

    /// 增量处理会话变更，避免整页重拉
    private func handleConversationDidChangeNotification(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let typeRaw = userInfo[ConversationChangeUserInfoKey.type] as? String,
            let idRaw = userInfo[ConversationChangeUserInfoKey.conversationId] as? String,
            let type = ConversationChangeType(rawValue: typeRaw),
            let conversationId = UUID(uuidString: idRaw)
        else {
            return
        }

        switch type {
        case .created:
            handleConversationCreated(conversationId)
        case .updated:
            handleConversationUpdated(conversationId)
        case .deleted:
            handleConversationDeleted(conversationId)
        }
    }

    private func handleConversationCreated(_ conversationId: UUID) {
        guard let conversation = conversationVM.fetchConversation(id: conversationId) else { return }
        guard !conversations.contains(where: { $0.id == conversationId }) else { return }

        conversations.insert(conversation, at: 0)
        nextOffset += 1
        syncSelectionFromViewModel()
    }

    private func handleConversationUpdated(_ conversationId: UUID) {
        guard let updatedConversation = conversationVM.fetchConversation(id: conversationId) else { return }
        guard let index = conversations.firstIndex(where: { $0.id == conversationId }) else { return }

        conversations[index] = updatedConversation
    }

    private func handleConversationDeleted(_ conversationId: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationId }) else { return }

        conversations.remove(at: index)
        nextOffset = max(0, nextOffset - 1)
        if conversations.count < pageSize {
            hasMore = true
        }
    }

    private func handleAgentConversationCreated(conversationId: UUID, proxy: ScrollViewProxy) {
        // 如果当前分页尚未包含新会话，先刷新第一页再尝试滚动到顶部。
        let containsRow = conversations.contains(where: { $0.id == conversationId })
        if !containsRow, !isLoadingPage {
            reloadFromFirstPage()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.2)) {
                // 滚动到绝对顶部锚点，避免 List 内部 padding 导致未到顶
                proxy.scrollTo(listTopAnchorId, anchor: .top)
            }
        }
    }

    /// 如果会话关联了项目，切换到该项目
    /// - Parameter conversation: 选中的会话
    private func switchToProjectIfNeeded(for conversation: Conversation) {
        guard let projectId = conversation.projectId else {
            if Self.verbose {
                ConversationListPlugin.logger.info("\(self.t)📁 会话「\(conversation.title)」未关联项目")
            }
            return
        }
        
        // 检查项目路径是否有效
        let projectPath = projectId
        guard FileManager.default.fileExists(atPath: projectPath) else {
            ConversationListPlugin.logger.warning("\(self.t)⚠️ 会话关联的项目不存在：\(projectPath)")
            return
        }
        
        // 检查当前项目是否已经是目标项目
        if projectVM.currentProject?.path == projectPath {
            if Self.verbose {
                ConversationListPlugin.logger.info("\(self.t)✅ 已是当前项目，无需切换：\(projectPath)")
            }
            return
        }
        
        // 创建 Project 对象并切换
        let projectName = URL(fileURLWithPath: projectPath).lastPathComponent
        let project = Project(name: projectName, path: projectPath, lastUsed: Date())
        
        projectVM.switchProject(to: project)
        
        if Self.verbose {
            ConversationListPlugin.logger.info("\(self.t)🔄 已切换到项目：\(projectName) (\(projectPath))")
        }
    }
}

// MARK: - Event Handler

extension ConversationListView {
    /// 处理会话列表变化
    func handleConversationsChanged(_ newConversations: [Conversation]) {
        // 如果当前选中的会话不在新列表中，清除选择
        if let localId = localSelectedConversationId {
            if !newConversations.contains(where: { $0.id == localId }) {
                ConversationListPlugin.logger.info("\(self.t)⚠️ 当前选中的会话已不在列表中，清除选择")
                localSelectedConversationId = nil
            }
        }
    }

    /// 处理选择变化：同步到 ConversationVM
    func handleLocalSelectionChange() {
        // 只在值确实不同时才更新，避免循环
        guard localSelectedConversationId != conversationVM.selectedConversationId else {
            return
        }

        if let newId = self.localSelectedConversationId {
            if Self.verbose {
                ConversationListPlugin.logger.info("\(self.t)👉 [\(newId)] 从 List 选择会话")
            }
            self.conversationVM.setSelectedConversation(newId)
            
            // 选择会话时，切换到关联的项目
            if let conversation = conversations.first(where: { $0.id == newId }) {
                switchToProjectIfNeeded(for: conversation)
            }
        } else {
            if Self.verbose {
                ConversationListPlugin.logger.info("\(self.t)👉 清除会话选择")
            }
            self.conversationVM.setSelectedConversation(nil)
        }
    }

    func handleConversationSelected() {
        let localId = localSelectedConversationId?.uuidString ?? "nil"
        let vmId = conversationVM.selectedConversationId?.uuidString ?? "nil"
        if Self.verbose {
            ConversationListPlugin.logger.info("\(self.t)🔄 handleConversationSelected called: local=\(localId), vm=\(vmId)")
        }

        // 只在值确实不同时才更新，避免循环
        guard localSelectedConversationId != conversationVM.selectedConversationId else {
            return
        }

        if let conversationId = self.conversationVM.selectedConversationId {
            // 新会话通常会成为当前选中项，如果当前分页中没有，先刷新第一页
            if self.conversations.first(where: { $0.id == conversationId }) == nil {
                if lastReloadSelectionId != conversationId {
                    lastReloadSelectionId = conversationId
                    reloadFromFirstPage()
                } else if Self.verbose {
                    ConversationListPlugin.logger.info("\(self.t)⏭️ 跳过重复分页重载: \(conversationId)")
                }
            }

            if self.conversations.first(where: { $0.id == conversationId }) != nil {
                if Self.verbose {
                    ConversationListPlugin.logger.info("\(self.t)👉 同步 VM 选择到 List: \(conversationId)")
                }
                self.localSelectedConversationId = conversationId
                lastReloadSelectionId = nil
            }
        } else {
            self.localSelectedConversationId = nil
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
