import Foundation
import SwiftUI
import SwiftData

/// 请求日志状态栏数据浏览器 ViewModel
@MainActor
public final class RequestLogBrowserViewModel: ObservableObject {
    @Published var items: [RequestLogItemDTO] = []
    @Published var stats: RequestLogStats = .init()
    @Published var isLoading = false
    @Published var currentPage = 1
    @Published var filterSuccess: Bool? = nil  // nil = all, true = success, false = failed

    private let pageSize = 50

    public var totalPages: Int {
        let total = stats.totalRequests
        return max(1, (total + pageSize - 1) / pageSize)
    }

    public var totalDisplayCount: Int {
        items.count
    }

    public func reload() async {
        isLoading = true
        await fetchStats()
        await fetchItems()
        isLoading = false
    }

    public func nextPage() {
        guard currentPage < totalPages else { return }
        currentPage += 1
        Task { await fetchItems() }
    }

    public func previousPage() {
        guard currentPage > 1 else { return }
        currentPage -= 1
        Task { await fetchItems() }
    }

    // MARK: - Private

    private func fetchStats() async {
        stats = await RequestLogHistoryManager.shared.getStats()
    }

    private func fetchItems() async {
        let offset = (currentPage - 1) * pageSize
        if let filter = filterSuccess {
            items = await RequestLogHistoryManager.shared.query(
                isSuccess: filter,
                limit: pageSize,
                offset: offset
            )
        } else {
            items = await RequestLogHistoryManager.shared.getLatest(
                limit: pageSize,
                offset: offset
            )
        }
    }
}
