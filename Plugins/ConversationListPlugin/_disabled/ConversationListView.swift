import Combine
import LumiKernel
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
    @ObservedObject private var context: ConversationListContext

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

    public init(context: ConversationListContext) {
        self.context = context
        self.selectionStore = ConversationListLocalStore(databaseDirectory: context.databaseDirectory())
    }

    public var body: some View {
        VStack(spacing: 0) {
            if conversations.isEmpty {
                if isLoadingPage {
                    loadingView
                } else {
                    ConversationListEmptyView()
                }
            } else {
                conversationListContent
            }
        }
        .onAppear(perform: performInitialLoadIfNeeded)
        .onChange(of: localSelectedConversationId, handleLocalSelectionChange)
        .onChange(of: context.selectedConversationId, handleConversationSelected)
        .onChange(of: context.selectedConversationId) { _, newValue in
            selectionStore.saveSelectedConversationId(newValue)
        }
        .onChange(of: conversations) { _, newConversations in
            handleConversationsChanged(newConversations)
        }
        .onChange(of: context.lastChange) { _, change in
            guard let change else { return }
            handleConversationChange(change)
        }
        .onChange(of: context.statusVersion) { _, _ in }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - View

extension ConversationListView {
    private var loadingView: some View {
        ProgressView(LumiPluginLocalization.string("Loading...", bundle: .module))
            .font(.appMicro)
            .foregroundColor(theme.textSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.vertical, 12)
    }

    private var conversationListContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(conversations, id: \.id) { conversation in
                        // 用 onTapGesture 触发选中，绕过 AppListRow 内置 Button 对右键的吞吃，
                        // 让 ConversationItemView 上的 .contextMenu 在 macOS 上能正常弹出。
                        AppListRow(isSelected: localSelectedConversationId == conversation.id) {
                            ConversationItemView(
                                conversation: conversation,
                                onDelete: { handleDelete(conversation) },
                                isProcessing: context.isConversationProcessing(conversation.id)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                localSelectedConversationId = conversation.id
                            }
                        }
                        .onAppear {
                            handleRowAppear(conversation)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .scrollContentBackground(.hidden)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

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
    private var currentSelectedConversationId: UUID? {
        context.selectedConversationId
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

        _ = context.deleteConversation(id: conversation.id)

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

    private func reloadFromFirstPage() {
        conversations = []
        nextOffset = 0
        hasMore = true
        loadNextPageIfNeeded()
    }

    private func handleRowAppear(_ conversation: ConversationListItem) {
        guard conversation.id == conversations.last?.id else { return }
        loadNextPageIfNeeded()
    }

    private func loadNextPageIfNeeded() {
        guard hasMore, !isLoadingPage else { return }

        isLoadingPage = true
        let page = context.fetchConversationsPage(limit: pageSize, offset: nextOffset)

        if nextOffset == 0 {
            conversations = page
        } else {
            let existingIds = Set(conversations.map(\.id))
            conversations.append(contentsOf: page.filter { !existingIds.contains($0.id) })
        }

        nextOffset += page.count
        hasMore = page.count == pageSize
        isLoadingPage = false

        ensureSelectedConversationVisible()
        syncSelectionFromContext()
    }

    private func restorePersistedSelectionIfNeeded() {
        guard !didRestoreSelection else { return }
        didRestoreSelection = true

        guard currentSelectedConversationId == nil,
              let restoredId = selectionStore.loadSelectedConversationId() else {
            return
        }

        guard context.fetchConversation(id: restoredId) != nil else {
            selectionStore.saveSelectedConversationId(nil)
            return
        }

        context.selectConversation(restoredId, reason: "conversationListRestoreSelection")
    }

    private func ensureSelectedConversationVisible() {
        guard let selectedId = currentSelectedConversationId,
              conversations.contains(where: { $0.id == selectedId }) == false,
              let selectedConversation = context.fetchConversation(id: selectedId) else {
            return
        }

        conversations.insert(selectedConversation, at: 0)
    }

    private func handleConversationChange(_ change: ConversationListChange) {
        switch change.type {
        case .created:
            handleConversationCreated(change.conversationId)
        case .updated:
            handleConversationUpdated(change.conversationId)
        case .deleted:
            handleConversationDeleted(change.conversationId)
        }
    }

    private func handleConversationCreated(_ conversationId: UUID) {
        guard let conversation = context.fetchConversation(id: conversationId) else { return }
        guard !conversations.contains(where: { $0.id == conversationId }) else { return }

        conversations.insert(conversation, at: 0)
        nextOffset += 1
        syncSelectionFromContext()
    }

    private func handleConversationUpdated(_ conversationId: UUID) {
        guard let updatedConversation = context.fetchConversation(id: conversationId) else { return }

        if let index = conversations.firstIndex(where: { $0.id == conversationId }) {
            conversations[index] = updatedConversation
        } else {
            // 本地数组中还没有这个对话（可能错过了 .created 事件）
            // 这种情况会在创建对话后标题立即更新时发生
            conversations.insert(updatedConversation, at: 0)
            nextOffset += 1
            syncSelectionFromContext()
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
        // 规则 1：未绑定项目 → 切到"无项目"态（传空串）。
        // 规则 2：绑定的项目目录即便已不存在，也照常切到该项目；
        //         真正使用该路径的消费者会在使用时报错给用户。
        let projectPath = conversation.projectPath ?? ""

        if Self.verbose, ConversationListPlugin.verbose {
            if projectPath.isEmpty {
                ConversationListPlugin.logger.info("\(self.t)📁 会话「\(conversation.displayTitle)」未关联项目，切到无项目态")
            } else {
                ConversationListPlugin.logger.info("\(self.t)📁 会话「\(conversation.displayTitle)」关联项目：\(projectPath)")
            }
        }

        context.switchProject(projectPath: projectPath, reason: "conversationListSelect")
    }
}

// MARK: - Event Handler

extension ConversationListView {
    public func handleConversationsChanged(_ newConversations: [ConversationListItem]) {
        if let localId = localSelectedConversationId,
           !newConversations.contains(where: { $0.id == localId }) {
            if Self.verbose, ConversationListPlugin.verbose {
                ConversationListPlugin.logger.info("\(self.t)⚠️ 当前选中的会话已不在列表中，清除选择")
            }
            localSelectedConversationId = nil
        }
    }

    public func handleLocalSelectionChange() {
        let currentSelected = currentSelectedConversationId
        guard localSelectedConversationId != currentSelected else { return }

        if let newId = localSelectedConversationId {
            if Self.verbose, ConversationListPlugin.verbose {
                ConversationListPlugin.logger.info("\(self.t)👉 [\(newId)] 从 List 选择会话")
            }

            context.selectConversation(newId, reason: "conversationListSelect")

            if let conversation = conversations.first(where: { $0.id == newId }) {
                switchToProjectIfNeeded(for: conversation)
            }
        } else {
            if Self.verbose, ConversationListPlugin.verbose {
                ConversationListPlugin.logger.info("\(self.t)👉 清除会话选择")
            }

            context.selectConversation(nil, reason: "conversationListClear")
        }
    }

    public func handleConversationSelected() {
        let localId = localSelectedConversationId?.uuidString ?? "nil"
        let selectedId = context.selectedConversationId

        let contextId = selectedId?.uuidString ?? "nil"
        if Self.verbose, ConversationListPlugin.verbose {
            ConversationListPlugin.logger.info("\(self.t)🔄 handleConversationSelected called: local=\(localId), context=\(contextId)")
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

            ensureSelectedConversationVisible()
            if conversations.first(where: { $0.id == conversationId }) != nil {
                localSelectedConversationId = conversationId
                lastReloadSelectionId = nil
            }
        } else {
            localSelectedConversationId = nil
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("对话列表 - 标准尺寸") {
    ConversationListView(context: ConversationListPreviewSupport.makeContext())
        .frame(width: 300, height: 600)
}

#Preview("对话列表 - 窄屏") {
    ConversationListView(context: ConversationListPreviewSupport.makeContext())
        .frame(width: 250, height: 400)
}
#endif
