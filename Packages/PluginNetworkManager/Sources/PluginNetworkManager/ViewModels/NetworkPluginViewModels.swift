import Foundation
import Combine

@MainActor
final class NetworkHistoryViewModel: ObservableObject {
    @Published private(set) var recentHistory: [NetworkDataPoint] = []
    @Published private(set) var longTermHistory: [NetworkDataPoint] = []

    func apply(recent: [NetworkDataPoint], longTerm: [NetworkDataPoint]) {
        recentHistory = recent
        longTermHistory = longTerm
    }

    /// 按时间范围裁剪历史数据。
    ///
    /// 1 小时范围取秒级高频缓冲,更长范围取分钟级聚合缓冲;
    /// 两者都按 `range.duration` 剔除过期样本,避免不同范围展示同一份数据。
    func data(for range: TimeRange) -> [NetworkDataPoint] {
        let buffer = range.usesHighResolutionBuffer ? recentHistory : longTermHistory
        return points(in: buffer, within: range.duration)
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
