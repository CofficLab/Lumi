import Foundation
import SwiftUI
import SwiftData

public protocol RequestLogHistoryQuerying: Sendable {
    func getStats() async -> RequestLogStats
    func getLatest(limit: Int, offset: Int) async -> [RequestLogItemDTO]
    func query(isSuccess: Bool, limit: Int, offset: Int) async -> [RequestLogItemDTO]
}

/// 请求日志状态栏数据浏览器 ViewModel
@MainActor
public final class RequestLogBrowserViewModel: ObservableObject {
    @Published var items: [RequestLogItemDTO] = []
    @Published var stats: RequestLogStats = .init()
    @Published var isLoading = false
    @Published var currentPage = 1
    @Published var filterSuccess: Bool? = nil  // nil = all, true = success, false = failed

    private let pageSize = 50
    private let history: any RequestLogHistoryQuerying
    private var reloadGeneration = 0

    public init(history: any RequestLogHistoryQuerying = RequestLogHistoryManager.shared) {
        self.history = history
    }

    public var totalPages: Int {
        let total = filteredTotalCount
        return max(1, (total + pageSize - 1) / pageSize)
    }

    public var totalDisplayCount: Int {
        items.count
    }

    public func reload() async {
        let generation = nextReloadGeneration()
        await reload(generation: generation)
    }

    public func setFilterSuccess(_ filter: Bool?) {
        guard filterSuccess != filter else { return }
        filterSuccess = filter
        currentPage = 1
        scheduleReload()
    }

    private func reload(generation: Int) async {
        isLoading = true
        defer {
            if isCurrentReload(generation) {
                isLoading = false
            }
        }

        let loadedStats = await history.getStats()
        guard isCurrentReload(generation) else { return }

        stats = loadedStats
        await fetchItems(generation: generation)
    }

    public func nextPage() {
        guard currentPage < totalPages else { return }
        currentPage += 1
        scheduleItemsFetch()
    }

    public func previousPage() {
        guard currentPage > 1 else { return }
        currentPage -= 1
        scheduleItemsFetch()
    }

    // MARK: - Private

    private func fetchItems(generation: Int) async {
        normalizeCurrentPage()
        let offset = max((currentPage - 1) * pageSize, 0)
        let loadedItems: [RequestLogItemDTO]
        if let filter = filterSuccess {
            loadedItems = await history.query(
                isSuccess: filter,
                limit: pageSize,
                offset: offset
            )
        } else {
            loadedItems = await history.getLatest(
                limit: pageSize,
                offset: offset
            )
        }
        guard isCurrentReload(generation) else { return }

        items = loadedItems
    }

    private var filteredTotalCount: Int {
        switch filterSuccess {
        case nil:
            stats.totalRequests
        case true:
            stats.successCount
        case false:
            stats.failedCount
        }
    }

    private func normalizeCurrentPage() {
        let normalized = min(max(currentPage, 1), totalPages)
        if currentPage != normalized {
            currentPage = normalized
        }
    }

    private func scheduleReload() {
        let generation = nextReloadGeneration()
        Task { await reload(generation: generation) }
    }

    private func scheduleItemsFetch() {
        let generation = nextReloadGeneration()
        Task { await fetchItems(generation: generation) }
    }

    private func nextReloadGeneration() -> Int {
        reloadGeneration += 1
        return reloadGeneration
    }

    private func isCurrentReload(_ generation: Int) -> Bool {
        generation == reloadGeneration
    }
}

extension RequestLogHistoryManager: RequestLogHistoryQuerying {}
