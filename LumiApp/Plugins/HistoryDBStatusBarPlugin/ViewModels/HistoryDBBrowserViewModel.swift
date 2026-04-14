import SwiftUI
import SwiftData

@MainActor
final class HistoryDBBrowserViewModel: ObservableObject {
    // MARK: - UI State

    @Published var selectedMode: HistoryDBViewMode = .messages {
        didSet {
            if oldValue != selectedMode {
                currentPage = 1
                Task { await reload() }
            }
        }
    }

    @Published var pageSize: Int = 50 {
        didSet {
            if oldValue != pageSize {
                currentPage = 1
                Task { await reload() }
            }
        }
    }

    @Published var currentPage: Int = 1
    @Published private(set) var totalCount: Int = 0
    @Published private(set) var messageRows: [HistoryMessageRow] = []
    @Published private(set) var conversationRows: [HistoryConversationRow] = []
    @Published private(set) var isLoading: Bool = false

    // MARK: - Dependencies

    private let chatHistoryVM: ChatHistoryVM
    private let conversationVM: ConversationVM

    init(chatHistoryVM: ChatHistoryVM, conversationVM: ConversationVM) {
        self.chatHistoryVM = chatHistoryVM
        self.conversationVM = conversationVM
    }

    var totalPages: Int {
        let pages = Int(ceil(Double(totalCount) / Double(max(pageSize, 1))))
        return max(pages, 1)
    }

    var offset: Int {
        max((currentPage - 1) * pageSize, 0)
    }

    func nextPage() {
        guard currentPage < totalPages else { return }
        currentPage += 1
        Task { await reload() }
    }

    func previousPage() {
        guard currentPage > 1 else { return }
        currentPage -= 1
        Task { await reload() }
    }

    func goToFirstPage() {
        guard currentPage != 1 else { return }
        currentPage = 1
        Task { await reload() }
    }

    func reload() async {
        isLoading = true
        defer { isLoading = false }

        switch selectedMode {
        case .messages:
            await loadMessageRows()
        case .conversations:
            await loadConversationRows()
        }
    }

    // MARK: - Loaders

    private func loadMessageRows() async {
        let context = chatHistoryVM.chatHistoryService.getContext()

        do {
            let countDescriptor = FetchDescriptor<ChatMessageEntity>()
            let entities = try context.fetch(countDescriptor)
            totalCount = entities.count

            var descriptor = FetchDescriptor<ChatMessageEntity>(
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            descriptor.fetchOffset = offset
            descriptor.fetchLimit = pageSize

            let pageEntities = try context.fetch(descriptor)
            messageRows = pageEntities.map { entity in
                let modelName = entity.modelName ?? "-"
                let roleText = entity.role.rawValue
                let conversation = entity.conversation
                let conversationTitle = conversation?.title ?? "-"
                let conversationId = conversation?.id ?? UUID()
                let metrics = entity.metrics
                let tokens = metrics?.totalTokens ?? 0
                let preview = entity.content
                    .replacingOccurrences(of: "\n", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                return HistoryMessageRow(
                    id: entity.id,
                    conversationId: conversationId,
                    conversationTitle: conversationTitle,
                    role: roleText,
                    model: modelName,
                    tokens: tokens,
                    timestamp: entity.timestamp,
                    contentPreview: preview
                )
            }

            conversationRows = []
        } catch {
            totalCount = 0
            messageRows = []
        }
    }

    private func loadConversationRows() async {
        let all = conversationVM.fetchAllConversations()
        totalCount = all.count

        let slice = all.dropFirst(offset).prefix(pageSize)
        conversationRows = slice.map { conversation in
            let count = (chatHistoryVM.loadMessagesAsync(forConversationId: conversation.id) ?? []).count
            return HistoryConversationRow(
                id: conversation.id,
                title: conversation.title,
                projectId: conversation.projectId ?? "-",
                createdAt: conversation.createdAt,
                updatedAt: conversation.updatedAt,
                messageCount: count
            )
        }

        messageRows = []
    }
}
