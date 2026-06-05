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
                maxWidth: .infinity,
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
    private let creationScrollAnimation = Animation.easeOut(duration: 0.18)

    var body: some View {
        ScrollViewReader { proxy in
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
                            ConversationRow(
                                item: item,
                                isProcessing: context.isConversationProcessing(item.id)
                            )
                                .id(item.id)
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
                handleConversationChange(change, proxy: proxy)
            }
            .onChange(of: context.statusVersion) { _, _ in }
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

    private func handleConversationChange(_ change: ConversationListChange, proxy: ScrollViewProxy) {
        switch change.type {
        case .created:
            if let item = context.fetchConversation(id: change.conversationId),
               !conversations.contains(where: { $0.id == change.conversationId }) {
                conversations.insert(item, at: 0)
                nextOffset += 1
                selectedId = item.id
                scrollToConversation(item.id, proxy: proxy)
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

    private func scrollToConversation(_ id: UUID, proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation(creationScrollAnimation) {
                proxy.scrollTo(id, anchor: .top)
            }
        }
    }
}

/// 单行对话列表项
struct ConversationRow: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    let item: ConversationListItem
    let isProcessing: Bool

    private let recentActivityWindow: TimeInterval = 5 * 60

    private var isRecentlyActive: Bool {
        Date().timeIntervalSince(item.updatedAt) < recentActivityWindow
    }

    var body: some View {
        HStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.appMicro)
                    .foregroundColor(isProcessing ? theme.primary : theme.textTertiary)
                    .padding(3)

                if isProcessing {
                    ProcessingPulseIndicator(color: theme.primary)
                } else if isRecentlyActive {
                    RecentActivityIndicator(color: theme.primary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayTitle)
                    .font(.appMicroEmphasized)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                metadataSection
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var metadataSection: some View {
        HStack(spacing: 4) {
            if let projectPath = item.projectPath {
                Text(URL(fileURLWithPath: projectPath).lastPathComponent)
                    .font(.appMicro)
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(1)

                Text(verbatim: "•")
                    .font(.appMicro)
                    .foregroundColor(theme.textTertiary)
            }

            Text(item.updatedAt, style: .relative)
                .font(.appMicro)
                .foregroundColor(theme.textSecondary)
        }
    }
}

private struct ProcessingPulseIndicator: View {
    let color: Color

    @State private var isAnimating = false

    var body: some View {
        Circle()
            .fill(color.opacity(0.3))
            .frame(width: 12, height: 12)
            .scaleEffect(isAnimating ? 1.8 : 1.0)
            .opacity(isAnimating ? 0 : 0.5)
            .animation(
                .easeOut(duration: 1.5).repeatForever(autoreverses: false),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

private struct RecentActivityIndicator: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 4, height: 4)
            .offset(x: 4, y: -4)
    }
}
