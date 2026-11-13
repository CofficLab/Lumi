import Combine
import Foundation
import Testing
@testable import PluginNetworkManager

/// 回归 #216：每个 1Hz 采样 tick 必须只发布一个原子快照，
/// 历史记录边界每个快照只写入一个点（修复前 combineLatest 每 tick 写 4 个点，
/// 3600 上限实际只覆盖约 15 分钟）。
///
/// 用例共享 `NetworkService.shared` / `NetworkHistoryService.shared` 单例，
/// 必须串行执行，避免互相污染快照计数与历史条数。
@Suite(.serialized)
@MainActor
struct NetworkUsageSnapshotTests {

    @Test
    func samplingTickPublishesExactlyOneAtomicSnapshot() async throws {
        let service = NetworkService.shared
        service.startMonitoring()
        defer { service.stopMonitoring() }

        var snapshots: [NetworkUsageSnapshot] = []
        var cancellables = Set<AnyCancellable>()
        service.$usageSnapshot
            .dropFirst()
            .sink { snapshots.append($0) }
            .store(in: &cancellables)

        for _ in 0..<3 {
            service.updateNetworkUsage()
            let deadline = Date().addingTimeInterval(5)
            while service.isSampling {
                if Date() > deadline {
                    Issue.record("Sampling tick did not finish within 5 seconds")
                    break
                }
                await Task.yield()
            }
        }

        // 修复前：四个 @Published 逐个赋值，combineLatest 每 tick 发射 4 次。
        #expect(snapshots.count == 3)
        let last = try #require(snapshots.last)
        #expect(last.downloadSpeed == service.downloadSpeed)
        #expect(last.uploadSpeed == service.uploadSpeed)
        #expect(last.totalDownload == service.totalDownload)
        #expect(last.totalUpload == service.totalUpload)
    }

    @Test
    func usageRecordingWritesOneHistoryPointPerSnapshot() {
        let subject = PassthroughSubject<NetworkUsageSnapshot, Never>()
        var recorded: [(down: Double, up: Double)] = []
        var applied: [NetworkUsageSnapshot] = []
        let cancellable = NetworkMetricsObserver.observeUsageSnapshots(
            subject.eraseToAnyPublisher(),
            record: { down, up in recorded.append((down, up)) },
            apply: { applied.append($0) }
        )
        defer { cancellable.cancel() }

        for index in 1...3 {
            subject.send(NetworkUsageSnapshot(
                downloadSpeed: Double(index) * 100,
                uploadSpeed: Double(index) * 10,
                totalDownload: UInt64(index) * 1_000,
                totalUpload: UInt64(index) * 500
            ))
        }

        #expect(recorded.count == 3)
        #expect(applied.count == 3)
        #expect(recorded.map(\.down) == [100, 200, 300])
        #expect(recorded.map(\.up) == [10, 20, 30])
    }

    @Test
    func usageRecordingKeepsSnapshotFieldsAtomic() {
        let subject = PassthroughSubject<NetworkUsageSnapshot, Never>()
        var recorded: [(down: Double, up: Double)] = []
        var applied: [NetworkUsageSnapshot] = []
        let cancellable = NetworkMetricsObserver.observeUsageSnapshots(
            subject.eraseToAnyPublisher(),
            record: { down, up in recorded.append((down, up)) },
            apply: { applied.append($0) }
        )
        defer { cancellable.cancel() }

        let snapshot = NetworkUsageSnapshot(
            downloadSpeed: 120,
            uploadSpeed: 34,
            totalDownload: 1_000,
            totalUpload: 500
        )
        subject.send(snapshot)

        #expect(recorded.count == 1)
        #expect(recorded.first?.down == 120)
        #expect(recorded.first?.up == 34)
        #expect(applied == [snapshot])
    }

    @Test
    func observerRecordsExactlyOneHistoryPointPerPublishedSnapshot() {
        // 直接构造真实 observer，验证 init 的接线确实订阅快照发布器，
        // 且只记录新发布的快照：@Published 订阅时重放的当前值不得再记一点。
        // 全程同步执行、不让出主 actor：init 里的慢统计 Task 尚未运行，
        // observer 释放后其 weak self 守卫会直接返回，不产生网络请求。
        let history = NetworkHistoryService.shared
        let before = history.recentHistory.count
        let viewModels = NetworkPluginViewModels()
        let observer = NetworkMetricsObserver(viewModels: viewModels)

        NetworkService.shared.usageSnapshot = NetworkUsageSnapshot(
            downloadSpeed: 120,
            uploadSpeed: 34,
            totalDownload: 1_000,
            totalUpload: 500
        )

        #expect(history.recentHistory.count == before + 1)
        #expect(history.recentHistory.last?.downloadSpeed == 120)
        #expect(history.recentHistory.last?.uploadSpeed == 34)
        #expect(viewModels.network.networkState.downloadSpeed == 120)
        #expect(viewModels.network.networkState.totalUpload == 500)

        observer.cancel()
    }
}