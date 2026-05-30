import SwiftUI

@MainActor
public final class HistoryDBBrowserViewModel: ObservableObject {
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

    public init() {}

    public var totalPages: Int {
        let pages = Int(ceil(Double(totalCount) / Double(max(pageSize, 1))))
        return max(pages, 1)
    }

    public var offset: Int {
        max((currentPage - 1) * pageSize, 0)
    }

    public func nextPage() {
        guard currentPage < totalPages else { return }
        currentPage += 1
        Task { await reload() }
    }

    public func previousPage() {
        guard currentPage > 1 else { return }
        currentPage -= 1
        Task { await reload() }
    }

    public func goToFirstPage() {
        guard currentPage != 1 else { return }
        currentPage = 1
        Task { await reload() }
    }

    public func reload() async {
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
        totalCount = 0
        messageRows = []
        conversationRows = []
    }

    private func loadConversationRows() async {
        totalCount = 0
        conversationRows = []
        messageRows = []
    }
}
