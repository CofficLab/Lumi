import Foundation
import Combine

@MainActor
final class NetworkHistoryViewModel: ObservableObject {
    @Published private(set) var recentHistory: [NetworkDataPoint] = []
    @Published private(set) var longTermHistory: [NetworkDataPoint] = []

    /// 各时间范围裁剪结果的缓存。
    ///
    /// 裁剪是对整份缓冲做一次线性扫描，而图表视图每次 hover 更新都会重新
    /// 求值 `data(for:)`，30 天范围下是数万次元素操作（见 issue #1211）。
    /// 这里按范围缓存，缓冲或范围变化时失效。
    private var rangeCache: [TimeRange: [NetworkDataPoint]] = [:]

    /// 应用高频缓冲（每个采样 tick 调用一次）。
    ///
    /// 只发布 `recentHistory` 并只失效高频范围的缓存：recent-only 的采样
    /// 不得唤醒未变化的长期图表（30 天视图）重算（#1214）。
    func applyRecent(_ points: [NetworkDataPoint]) {
        recentHistory = points
        // 高频缓冲变化只失效高频范围（hour1）的缓存。
        rangeCache = rangeCache.filter { !$0.key.usesHighResolutionBuffer }
    }

    /// 应用长期缓冲（分钟聚合或历史恢复时调用）。
    func applyLongTerm(_ points: [NetworkDataPoint]) {
        longTermHistory = points
        // 长期缓冲变化只失效长期范围的缓存，hour1 不受影响。
        rangeCache = rangeCache.filter { $0.key.usesHighResolutionBuffer }
    }

    /// 按时间范围裁剪历史数据。
    ///
    /// 1 小时范围取秒级高频缓冲,更长范围取分钟级聚合缓冲;
    /// 两者都按 `range.duration` 剔除过期样本,避免不同范围展示同一份数据。
    func data(for range: TimeRange) -> [NetworkDataPoint] {
        if let cached = rangeCache[range] {
            return cached
        }
        let buffer = range.usesHighResolutionBuffer ? recentHistory : longTermHistory
        let result = points(in: buffer, within: range.duration)
        rangeCache[range] = result
        return result
    }

    /// 取最近若干秒的样本。
    ///
    /// 用于「最近 N 秒」这类固定窗口的迷你趋势图:按时间裁剪而不是按条数,
    /// 采样频率变化或休眠后也不会混入过期的点。
    func points(inLastSeconds seconds: TimeInterval) -> [NetworkDataPoint] {
        points(in: recentHistory, within: seconds)
    }

    private func points(in buffer: [NetworkDataPoint], within seconds: TimeInterval) -> [NetworkDataPoint] {
        let cutoff = Date().timeIntervalSince1970 - seconds
        return buffer.filter { $0.timestamp >= cutoff }
    }
}

@MainActor
final class NetworkPluginViewModels {
    let network = NetworkManagerViewModel()
    let history = NetworkHistoryViewModel()
}
