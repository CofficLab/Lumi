import SwiftUI
import LumiCoreKit
import LumiUI

public struct ChatPanelView: View {
    @EnvironmentObject private var context: ConversationListContext

    public var body: some View {
        let databaseDirectory = context.databaseDirectory()
        let preferredWidth = SplitWidth.preferredWidth(databaseDirectory: databaseDirectory)

        ConversationListView(context: context)
            .frame(
                minWidth: SplitWidth.defaultMinimumWidth,
                idealWidth: preferredWidth,
                maxWidth: SplitWidth.defaultMaximumWidth,
                maxHeight: .infinity
            )
            .background(
                SplitWidthPersistence(
                    config: .default(databaseDirectory: databaseDirectory)
                )
            )
    }
}

/// 对话列表视图，使用 ConversationListContext 驱动。
///
/// 通过 @EnvironmentObject 获取内核注入的 ConversationListContext，
/// 实现分页加载、选中同步、变更响应等功能。
struct ConversationListView: View {
    @ObservedObject var context: ConversationListContext

    @State private var conversations: [ConversationListItem] = []
    @State private var selectedId: UUID?
    @State private var nextOffset: Int = 0
    @State private var hasMore: Bool = true
    @State private var isLoadingPage: Bool = false
    @State private var didInitialLoad: Bool = false

    private let pageSize: Int = 40

    var body: some View {
        VStack(spacing: 0) {
            if conversations.isEmpty {
                if isLoadingPage {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    AppEmptyState(
                        icon: "message.fill",
                        title: String(localized: "No Conversations", bundle: .module)
                    )
                }
            } else {
                List(selection: $selectedId) {
                    ForEach(conversations) { item in
                        ConversationRow(item: item)
                            .tag(item.id)
                            .onAppear {
                                if item.id == conversations.last?.id {
                                    loadNextPage()
                                }
                            }
                    }
                }
                .listStyle(.plain)

                if isLoadingPage {
                    HStack {
                        Spacer()
                        ProgressView().controlSize(.small)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .onAppear(perform: initialLoad)
        .onChange(of: selectedId) { _, newId in
            if let newId {
                context.selectConversation(newId, reason: "chatPanelSelect")
            }
        }
        .onChange(of: context.selectedConversationId) { _, newId in
            if selectedId != newId {
                selectedId = newId
            }
        }
        .onChange(of: context.lastChange) { _, change in
            guard let change else { return }
            handleConversationChange(change)
        }
    }

    private func initialLoad() {
        guard !didInitialLoad else {
            selectedId = context.selectedConversationId
            return
        }
        didInitialLoad = true
        selectedId = context.selectedConversationId
        reloadFromFirstPage()
    }

    private func reloadFromFirstPage() {
        conversations = []
        nextOffset = 0
        hasMore = true
        loadNextPage()
    }

    private func loadNextPage() {
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
    }

    private func handleConversationChange(_ change: ConversationListChange) {
        switch change.type {
        case .created:
            if let item = context.fetchConversation(id: change.conversationId),
               !conversations.contains(where: { $0.id == change.conversationId }) {
                conversations.insert(item, at: 0)
                nextOffset += 1
                selectedId = item.id
            }
        case .updated:
            if let updated = context.fetchConversation(id: change.conversationId),
               let index = conversations.firstIndex(where: { $0.id == change.conversationId }) {
                conversations[index] = updated
            }
        case .deleted:
            conversations.removeAll { $0.id == change.conversationId }
            nextOffset = max(0, nextOffset - 1)
            if conversations.count < pageSize { hasMore = true }
        }
    }
}

/// 单行对话列表项
struct ConversationRow: View {
    let item: ConversationListItem

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "message.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayTitle)
                    .lineLimit(1)
                Text(item.updatedAt, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
