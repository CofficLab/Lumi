import Foundation
import ProviderMessage
import SwiftUI

/// Rail 底部 token 趋势图的数据模型。
///
/// 从 `MessageManaging` 加载最近 30 天的 token 消耗数据，
/// 供 `RailTokenTrendView` 渲染折线图。
@MainActor
public final class RailTokenTrendViewModel: ObservableObject {
    /// 单日 token 数据点。
    struct DayPoint: Identifiable, Equatable {
        let date: Date
        let tokens: Int
        var id: Date { date }
    }

    /// 趋势图展示的天数。
    static let dayCount = 30

    @Published private(set) var days: [DayPoint] = []
    @Published private(set) var totalTokens: Int = 0
    @Published private(set) var isLoading = false

    private let messages: (any MessageManaging)?
    private var loadTask: Task<Void, Never>?

    init(messages: (any MessageManaging)?) {
        self.messages = messages
    }

    /// 加载最近 30 天的 token 消耗数据。
    func loadTrend() {
        guard let messages else { return }
        loadTask?.cancel()
        let task = Task { [weak self] in
            guard let self else { return }
            self.isLoading = true
            defer { self.isLoading = false }

            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            guard let start = calendar.date(byAdding: .day, value: -(Self.dayCount - 1), to: today) else {
                return
            }

            let tokenCounts = await messages.dailyTokenCountsAsync(since: start)
            guard !Task.isCancelled else { return }

            let points: [DayPoint] = (0..<Self.dayCount).compactMap { offset in
                guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
                return DayPoint(date: date, tokens: tokenCounts[date, default: 0])
            }

            self.days = points
            self.totalTokens = points.reduce(0) { $0 + $1.tokens }
        }
        loadTask = task
    }
}
