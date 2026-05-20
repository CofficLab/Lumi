import Foundation
import SwiftUI
import SwiftData

/// 请求日志状态栏数据浏览器 ViewModel
@MainActor
final class RequestLogBrowserViewModel: ObservableObject {
    @Published var items: [RequestLogItemDTO] = []
    @Published var stats: RequestLogStats = .init()
    @Published var isLoading = false
    @Published var currentPage = 1
    @Published var filterSuccess: Bool? = nil  // nil = all, true = success, false = failed

    private let pageSize = 50

    var totalPages: Int {
        let total = stats.totalRequests
        return max(1, (total + pageSize - 1) / pageSize)
    }

    var totalDisplayCount: Int {
        items.count
    }

    func reload() async {
        isLoading = true
        await fetchStats()
        await fetchItems()
        isLoading = false
    }

    func nextPage() {
        guard currentPage < totalPages else { return }
        currentPage += 1
        Task { await fetchItems() }
    }

    func previousPage() {
        guard currentPage > 1 else { return }
        currentPage -= 1
        Task { await fetchItems() }
    }

    // MARK: - Private

    private func fetchStats() async {
        stats = await RequestLogHistoryManager.shared.getStats()
    }

    private func fetchItems() async {
        if let filter = filterSuccess {
            let context = await RequestLogHistoryManager.shared.getContext()
            var descriptor = FetchDescriptor<RequestLogItem>(
                predicate: RequestLogItem.predicate(isSuccess: filter),
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            descriptor.fetchLimit = pageSize
            descriptor.fetchOffset = (currentPage - 1) * pageSize
            let items = (try? context.fetch(descriptor)) ?? []
            self.items = items.map { RequestLogItemDTO(from: $0) }
        } else {
            let allItems = await RequestLogHistoryManager.shared.getLatest(limit: 1000)
            let startIndex = (currentPage - 1) * pageSize
            let endIndex = min(startIndex + pageSize, allItems.count)
            if startIndex < allItems.count {
                self.items = Array(allItems[startIndex..<endIndex])
            } else {
                self.items = []
            }
        }
    }
}
