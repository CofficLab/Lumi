import SwiftUI
import LumiCoreKit

@MainActor
public final class BrowserViewModel: ObservableObject {
    static let defaultPageSize = 50
    static let maxPageSize = 500

    // MARK: - Dependencies

    private let historyService: (any HistoryQueryService)?

    // MARK: - UI State

    @Published var selectedMode: ViewMode = .messages {
        didSet {
            if oldValue != selectedMode {
                currentPage = 1
                Task { await reload() }
            }
        }
    }

    @Published var pageSize: Int = defaultPageSize {
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

    public init(historyService: (any HistoryQueryService)? = nil) {
        self.historyService = historyService
    }

    public var totalPages: Int {
        let pages = Int(ceil(Double(totalCount) / Double(effectivePageSize)))
        return max(pages, 1)
    }

    public var offset: Int {
        let page = Self.normalizedPage(currentPage, totalPages: totalPages)
        return max((page - 1) * effectivePageSize, 0)
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
        guard let service = historyService else {
            totalCount = 0
            messageRows = []
            conversationRows = []
            return
        }

        isLoading = true
        defer { isLoading = false }

        switch selectedMode {
        case .messages:
            await loadMessageRows(service: service)
        case .conversations:
            await loadConversationRows(service: service)
        }
    }

    // MARK: - Loaders

    private func loadMessageRows(service: any HistoryQueryService) async {
        totalCount = await service.fetchMessageCount()
        normalizeCurrentPageForLoadedCount()
        messageRows = await service.fetchMessagePage(limit: effectivePageSize, offset: offset)
        conversationRows = []
    }

    private func loadConversationRows(service: any HistoryQueryService) async {
        totalCount = await service.fetchConversationCount()
        normalizeCurrentPageForLoadedCount()
        conversationRows = await service.fetchConversationPage(limit: effectivePageSize, offset: offset)
        messageRows = []
    }

    private var effectivePageSize: Int {
        Self.normalizedPageSize(pageSize)
    }

    private func normalizeCurrentPageForLoadedCount() {
        let normalized = Self.normalizedPage(currentPage, totalPages: totalPages)
        if normalized != currentPage {
            currentPage = normalized
        }
    }

    static func normalizedPageSize(_ rawValue: Int) -> Int {
        min(max(rawValue, 1), maxPageSize)
    }

    static func normalizedPage(_ rawValue: Int, totalPages: Int) -> Int {
        min(max(rawValue, 1), max(totalPages, 1))
    }
}
