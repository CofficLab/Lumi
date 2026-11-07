import Foundation
import Testing
@testable import PluginNetworkManager

/// 网络历史视图模型按时间范围裁剪数据的行为。
@Suite("NetworkHistoryViewModel")
@MainActor
struct NetworkHistoryViewModelTests {

    @Test("1 小时范围取高频缓冲并剔除过期样本")
    func oneHourRangeUsesHighResolutionBuffer() {
        let viewModel = NetworkHistoryViewModel()
        let now = Date().timeIntervalSince1970

        viewModel.apply(
            recent: [
                NetworkDataPoint(timestamp: now - 60, downloadSpeed: 100, uploadSpeed: 50),
                NetworkDataPoint(timestamp: now - 7200, downloadSpeed: 200, uploadSpeed: 60),
            ],
            longTerm: []
        )

        let points = viewModel.data(for: .hour1)

        #expect(points.count == 1)
        #expect(points.first?.downloadSpeed == 100)
    }

    @Test("4 小时范围剔除超出范围的长期样本")
    func fourHourRangeTrimsLongTermBuffer() {
        let viewModel = NetworkHistoryViewModel()
        let now = Date().timeIntervalSince1970

        viewModel.apply(
            recent: [],
            longTerm: [
                NetworkDataPoint(timestamp: now - 3600, downloadSpeed: 300, uploadSpeed: 70),
                NetworkDataPoint(timestamp: now - 14401, downloadSpeed: 400, uploadSpeed: 80),
            ]
        )

        let points = viewModel.data(for: .hour4)

        #expect(points.count == 1)
        #expect(points.first?.downloadSpeed == 300)
    }

    @Test("24 小时与 30 天范围返回不同的数据量")
    func differentLongRangesReturnDifferentData() {
        let viewModel = NetworkHistoryViewModel()
        let now = Date().timeIntervalSince1970

        viewModel.apply(
            recent: [],
            longTerm: [
                NetworkDataPoint(timestamp: now - 3600, downloadSpeed: 100, uploadSpeed: 10),
                NetworkDataPoint(timestamp: now - 43200, downloadSpeed: 200, uploadSpeed: 20),
                NetworkDataPoint(timestamp: now - 86401, downloadSpeed: 300, uploadSpeed: 30),
            ]
        )

        let day = viewModel.data(for: .hour24)
        let month = viewModel.data(for: .month1)

        #expect(day.count == 2)
        #expect(month.count == 3)
        #expect(day.count != month.count)
    }

    @Test("迷你趋势图按时间窗口取样而非按条数")
    func miniTrendUsesTimeWindow() {
        let viewModel = NetworkHistoryViewModel()
        let now = Date().timeIntervalSince1970

        viewModel.apply(
            recent: [
                NetworkDataPoint(timestamp: now - 10, downloadSpeed: 100, uploadSpeed: 10),
                NetworkDataPoint(timestamp: now - 30, downloadSpeed: 200, uploadSpeed: 20),
                // 90 秒前的点:按条数取 60 条会带上它,按时间窗口则应被剔除。
                NetworkDataPoint(timestamp: now - 90, downloadSpeed: 300, uploadSpeed: 30),
            ],
            longTerm: []
        )

        let points = viewModel.points(inLastSeconds: 60)

        #expect(points.count == 2)
        #expect(!points.contains { $0.downloadSpeed == 300 })
    }
}
