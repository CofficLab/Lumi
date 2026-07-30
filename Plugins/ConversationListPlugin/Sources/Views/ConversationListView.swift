import Combine
import LumiKernel
import LumiUI
import SuperLogKit
import SwiftUI

/// 对话列表视图
/// 使用分页方式渲染会话列表，避免一次性加载全部历史记录。
public struct ConversationListView: View, SuperLog {
    public nonisolated static let emoji = "🐶"
    public nonisolated static let verbose: Bool = true

    @LumiUI.LumiTheme private var theme: any LumiUITheme
    @StateObject private var store: ConversationListStore

    private let selectionStore: ConversationListLocalStore
    @State private var conversations: [ConversationListItem] = []
    @State private var localSelectedConversationId: UUID?
    @State private var nextOffset: Int = 0
    @State private var hasMore: Bool = true
    @State private var isLoadingPage: Bool = false
    @State private var didInitialLoad: Bool = false
    @State private var didRestoreSelection: Bool = false
    @State private var lastReloadSelectionId: UUID?

    private let pageSize: Int = 40

    public init(kernel: LumiKernel) {
        _store = StateObject(wrappedValue: ConversationListStore(kernel: kernel))
        self.selectionStore = ConversationListLocalStore(
            storageDirectory: ConversationListRuntimeBridge.shared.storageDirectory ?? ConversationListRuntimeBridge.defaultStorageDirectory
        )
    }

    public var body: some View {
        VStack(spacing: 0) {
            if conversations.isEmpty {
                if isLoadingPage {
                    ListLoadingView()
                } else {
                    ConversationListEmptyView()
                }
            } else {
                conversationListContent
            }
        }
        .onAppear(perform: performInitialLoadIfNeeded)
        .onChange(of: localSelectedConversationId, handleLocalSelectionChange)
        .onChange(of: store.selectedConversationId, handleConversationSelected)
        .onChange(of: store.selectedConversationId) { _, newValue in
            selectionStore.saveSelectedConversationId(newValue)
        }
        .onChange(of: conversations) { _, newConversations in
            handleConversationsChanged(newConversations)
        }
        .onChange(of: store.lastChange) { _, change in
            guard let change else { return }
            handleConversationChange(change)
        }
        .onChange(of: store.messageVersion) { _, _ in
            refreshVisibleMessageCounts()
        }
        .onChange(of: store.statusVersion, handleStatusVersionChanged)
        .onChange(of: store.sendingVersion) { _, _ in
            // 不需要做事;依赖 `isProcessing` 的视图节点会因为它读取的 SwiftUI
            // 依赖(这里就是 store.sendingVersion)变化而自动重渲染。
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - View

extension ConversationListView {
    private var conversationListContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(conversations, id: \.id) { conversation in
                        AppListRow(isSelected: localSelectedConversationId == conversation.id) {
                            ConversationItemView(
                                conversation: conversation,
                                onDelete: { handleDelete(conversation) },
                                onPin: { pinConversation(conversation) },
                                isProcessing: store.isConversationProcessing(conversation.id)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                localSelectedConversationId = conversation.id
                            }
                        }
                    }

                    if hasMore {
                        loadingMoreTrigger
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .scrollContentBackground(.hidden)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// 底部占位视图，始终渲染以触发 hasMore 时的下一页加载。
    private var loadingMoreTrigger: some View {
        Group {
            if isLoadingPage {
                HStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                    Spacer()
                }
                .padding(.vertical, 8)
            } else {
                Color.clear
                    .frame(height: 1)
                    .onAppear {
                        loadNextPageIfNeeded()
                    }
            }
        }
    }
}

// MARK: - Action

extension ConversationListView {
    private var currentSelectedConversationId: UUID? {
        store.selectedConversationId
    }

    private func syncSelectionFromContext() {
        let selectedId = currentSelectedConversationId

        if let selectedId {
            if conversations.first(where: { $0.id == selectedId }) != nil {
                if localSelectedConversationId != selectedId {
                    localSelectedConversationId = selectedId
                }
            } else {
                if Self.verbose, ConversationListPlugin.verbose {
                    ConversationListPlugin.logger.info("\(self.t)⚠️ [\(selectedId)] 选中的会话不存在于列表中")
                }
                localSelectedConversationId = nil
            }
        } else if localSelectedConversationId != nil {
            localSelectedConversationId = nil
        }
    }

    private func handleDelete(_ conversation: ConversationListItem) {
        if Self.verbose, ConversationListPlugin.verbose {
            ConversationListPlugin.logger.info("\(self.t)🗑️ 开始删除对话：\(conversation.displayTitle)")
        }

        if localSelectedConversationId == conversation.id {
            let remainingConversations = conversations.filter { $0.id != conversation.id }
            localSelectedConversationId = remainingConversations.first?.id
        }

        conversations.removeAll { $0.id == conversation.id }
        nextOffset = max(0, nextOffset - 1)
        if conversations.count < pageSize {
            hasMore = true
        }

        _ = store.deleteConversation(id: conversation.id)

        if Self.verbose && ConversationListPlugin.verbose {
            ConversationListPlugin.logger.info("\(self.t)🗑️ 删除完成：\(conversation.displayTitle) - 剩余 \(conversations.count) 条")
        }
    }

    private func performInitialLoadIfNeeded() {
        guard !didInitialLoad else {
            syncSelectionFromContext()
            return
        }

        didInitialLoad = true
        restorePersistedSelectionIfNeeded()
        reloadFromFirstPage()
    }

    /// 对话管理后台数据追上来了（statusVersion 变化），但 view 首屏还没拿到数据时，重试首次加载。
    private func handleStatusVersionChanged() {
        guard didInitialLoad, conversations.isEmpty, !isLoadingPage else { return }
        reloadFromFirstPage()
    }

    private func reloadFromFirstPage() {
        conversations = []
        nextOffset = 0
        hasMore = true
        loadNextPageIfNeeded()
    }

    private func refreshVisibleMessageCounts() {
        guard !conversations.isEmpty else { return }
        let currentConversations = conversations
        Task {
            let counts = await store.messageCounts(for: currentConversations.map(\.id))
            var updated: [ConversationListItem] = []
            updated.reserveCapacity(currentConversations.count)
            for conversation in currentConversations {
                let updatedCount = counts[conversation.id] ?? nil
                updated.append(ConversationListItem(
                    id: conversation.id,
                    projectPath: conversation.projectPath,
                    title: store.resolvedTitle(for: conversation.id),
                    createdAt: conversation.createdAt,
                    updatedAt: conversation.updatedAt,
                    providerID: conversation.providerID,
                    modelName: conversation.modelName,
                    messageCount: updatedCount,
                    order: conversation.order
                ))
            }
            conversations = updated
        }
    }

    private func loadNextPageIfNeeded() {
        guard hasMore, !isLoadingPage else { return }

        isLoadingPage = true
        let offset = nextOffset
        Task {
            let page = await store.fetchConversationsPage(limit: pageSize, offset: offset)

            if Self.verbose, ConversationListPlugin.verbose {
                ConversationListPlugin.logger.info("\(self.t)📄 loadNextPage offset=\(offset) page.count=\(page.count) hasMore_before=\(hasMore)")
            }

            await MainActor.run {
                if offset == 0 {
                    conversations = page
                } else {
                    conversations.append(contentsOf: page)
                }
                nextOffset = offset + page.count
                hasMore = page.count == pageSize
                isLoadingPage = false

                if !didRestoreSelection {
                    didRestoreSelection = true
                    syncSelectionFromContext()
                }
            }
        }
    }

    private func restorePersistedSelectionIfNeeded() {
        if let persistedId = selectionStore.loadSelectedConversationId(),
           conversations.contains(where: { $0.id == persistedId }) {
            localSelectedConversationId = persistedId
        }
    }

    private func handleConversationsChanged(_ newConversations: [ConversationListItem]) {
        if let localId = localSelectedConversationId,
           !newConversations.contains(where: { $0.id == localId }) {
            if Self.verbose, ConversationListPlugin.verbose {
                ConversationListPlugin.logger.info("\(self.t)⚠️ 当前选中的会话已不在列表中，清除选择")
            }
            localSelectedConversationId = nil
        }
    }

    private func handleConversationChange(_ change: ConversationListChange) {
        switch change.type {
        case .updated:
            handleConversationUpdated(change.conversationId)
        case .deleted:
            handleConversationDeleted(change.conversationId)
        case .created:
            // syncFromSource intentionally does not publish .created events.
            // New conversations are handled via handleStatusVersionChanged.
            break
        }
    }

    private func handleConversationUpdated(_ conversationId: UUID) {
        Task {
            guard let updatedConversation = await store.fetchConversation(id: conversationId) else { return }

            if let index = conversations.firstIndex(where: { $0.id == conversationId }) {
                conversations[index] = updatedConversation
            } else {
                conversations.insert(updatedConversation, at: 0)
                nextOffset += 1
                syncSelectionFromContext()
            }
        }
    }

    private func handleConversationDeleted(_ conversationId: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationId }) else { return }

        conversations.remove(at: index)
        nextOffset = max(0, nextOffset - 1)
        if conversations.count < pageSize {
            hasMore = true
        }
    }

    private func switchToProjectIfNeeded(for conversation: ConversationListItem) {
        let projectPath = conversation.projectPath ?? ""

        if Self.verbose, ConversationListPlugin.verbose {
            if projectPath.isEmpty {
                ConversationListPlugin.logger.info("\(self.t)📁 会话「\(conversation.displayTitle)」未关联项目，切到无项目态")
            } else {
                ConversationListPlugin.logger.info("\(self.t)📁 会话「\(conversation.displayTitle)」关联项目：\(projectPath)")
            }
        }

        store.switchProject(projectPath: projectPath, reason: "conversationListSelect")
    }

    private func pinConversation(_ conversation: ConversationListItem) {
        let newOrder = conversation.isPinned ? LumiConversationSummary.defaultOrder : 0
        store.setConversationOrder(newOrder, for: conversation.id)
    }
}

// MARK: - Event Handler

extension ConversationListView {
    public func handleLocalSelectionChange() {
        let currentSelected = currentSelectedConversationId
        guard localSelectedConversationId != currentSelected else { return }

        if let newId = localSelectedConversationId {
            if Self.verbose, ConversationListPlugin.verbose {
                ConversationListPlugin.logger.info("\(self.t)👉 [\(newId)] 从 List 选择会话")
            }

            store.selectConversation(newId, reason: "conversationListSelect")

            if let conversation = conversations.first(where: { $0.id == newId }) {
                switchToProjectIfNeeded(for: conversation)
            }
        } else {
            if Self.verbose, ConversationListPlugin.verbose {
                ConversationListPlugin.logger.info("\(self.t)👉 清除会话选择")
            }

            store.selectConversation(nil, reason: "conversationListClear")
        }
    }

    public func handleConversationSelected() {
        let localId = localSelectedConversationId?.uuidString ?? "nil"
        let selectedId = store.selectedConversationId

        let selectedID = selectedId?.uuidString ?? "nil"
        if Self.verbose, ConversationListPlugin.verbose {
            ConversationListPlugin.logger.info("\(self.t)🔄 handleConversationSelected called: local=\(localId), selected=\(selectedID)")
        }

        guard localSelectedConversationId != selectedId else { return }

        if let conversationId = selectedId {
            if conversations.first(where: { $0.id == conversationId }) == nil {
                if lastReloadSelectionId != conversationId {
                    lastReloadSelectionId = conversationId
                    reloadFromFirstPage()
                } else if Self.verbose, ConversationListPlugin.verbose {
                    ConversationListPlugin.logger.info("\(self.t)⏭️ 跳过重复分页重载: \(conversationId)")
                }
            }

            Task {
                await ensureSelectedConversationVisible()
                if conversations.first(where: { $0.id == conversationId }) != nil {
                    localSelectedConversationId = conversationId
                    lastReloadSelectionId = nil
                }
            }
        } else {
            localSelectedConversationId = nil
        }
    }

    private func ensureSelectedConversationVisible() async {
        guard let selectedId = store.selectedConversationId,
              !conversations.contains(where: { $0.id == selectedId }) else { return }

        if let conversation = await store.fetchConversation(id: selectedId) {
            await MainActor.run {
                if !conversations.contains(where: { $0.id == selectedId }) {
                    conversations.insert(conversation, at: 0)
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
    #Preview("对话列表 - 标准尺寸") {
        ConversationListView(kernel: ConversationListPreviewSupport.makeKernel())
            .frame(width: 300, height: 600)
    }

    #Preview("对话列表 - 窄屏") {
        ConversationListView(kernel: ConversationListPreviewSupport.makeKernel())
            .frame(width: 250, height: 400)
    }
#endif
