import Foundation
import ProviderGitRepositoryWatch
import Testing
@testable import PluginGitRepositoryWatch

/// 回归 #357：工作区变更节流（throttle）窗口内的最后一次变更曾被直接丢弃，
/// 没有尾随广播，已打开的 Changes 面板长期停在旧状态。这里用可注入的短节流窗口
/// 直接驱动 `broadcastWorkingTreeChangeIfAllowed()`，确定性地验证尾沿补发、合并与取消。
@Suite("Git 工作区节流尾随广播（#357）")
@MainActor
struct GitWorkingTreeThrottleTests {

    @Test("节流窗口内的变更必须在窗口结束后补发尾随广播（回归 #357）")
    func throttledChangeBroadcastsTrailingEdge() async throws {
        let provider = GitRepositoryWatchProvider(workingTreeChangeThrottle: 0.3)
        var events: [GitRepositoryWatchingEvent] = []
        let handle = provider.addObserver { events.append($0) }
        defer { handle.cancel() }

        provider.broadcastWorkingTreeChangeIfAllowed()
        #expect(workingTreeChangeCount(events) == 1, "首次变更应立即广播")

        provider.broadcastWorkingTreeChangeIfAllowed()
        #expect(workingTreeChangeCount(events) == 1, "节流窗口内不应立即广播")

        let sawTrailing = await waitUntil(timeout: 2) { workingTreeChangeCount(events) >= 2 }
        #expect(sawTrailing, "窗口结束后必须补发一次尾随广播，否则最后一次变更被永久丢弃")
        #expect(workingTreeChangeCount(events) == 2)
    }

    @Test("窗口内多次变更只合并成一次尾随广播（回归 #357）")
    func rapidChangesCoalesceIntoSingleTrailingBroadcast() async throws {
        let provider = GitRepositoryWatchProvider(workingTreeChangeThrottle: 0.3)
        var events: [GitRepositoryWatchingEvent] = []
        let handle = provider.addObserver { events.append($0) }
        defer { handle.cancel() }

        provider.broadcastWorkingTreeChangeIfAllowed()
        for _ in 0..<10 {
            provider.broadcastWorkingTreeChangeIfAllowed()
        }
        #expect(workingTreeChangeCount(events) == 1, "窗口内不得立即广播")

        let sawTrailing = await waitUntil(timeout: 2) { workingTreeChangeCount(events) >= 2 }
        #expect(sawTrailing)
        // 越过多个节流窗口：若每次变更各排一个尾随任务，会陆续补发多次，计数持续增长。
        try await Task.sleep(for: .milliseconds(600))
        #expect(workingTreeChangeCount(events) == 2, "多次变更必须合并成一次尾随广播，不得每次各发一次")
    }

    @Test("尾随广播后窗口重置，后续变更仍能补发（回归 #357）")
    func trailingBroadcastResetsWindow() async throws {
        let provider = GitRepositoryWatchProvider(workingTreeChangeThrottle: 0.3)
        var events: [GitRepositoryWatchingEvent] = []
        let handle = provider.addObserver { events.append($0) }
        defer { handle.cancel() }

        provider.broadcastWorkingTreeChangeIfAllowed()
        provider.broadcastWorkingTreeChangeIfAllowed()
        let sawSecond = await waitUntil(timeout: 2) { workingTreeChangeCount(events) >= 2 }
        #expect(sawSecond)

        provider.broadcastWorkingTreeChangeIfAllowed()
        let sawThird = await waitUntil(timeout: 2) { workingTreeChangeCount(events) >= 3 }
        #expect(sawThird, "尾随广播后窗口重置，后续变更仍须补发")
        #expect(workingTreeChangeCount(events) == 3)
    }

    @Test("停止监听后不再补发尾随广播（回归 #357）")
    func stopWatchingCancelsPendingTrailingBroadcast() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("GitWorkingTreeThrottle-stop-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent(".git", isDirectory: true),
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: root) }

        let provider = GitRepositoryWatchProvider(workingTreeChangeThrottle: 0.4)
        var events: [GitRepositoryWatchingEvent] = []
        let handle = provider.addObserver { events.append($0) }
        defer { handle.cancel() }

        provider.startWatching(repositoryURL: root)
        provider.broadcastWorkingTreeChangeIfAllowed()
        provider.broadcastWorkingTreeChangeIfAllowed()
        #expect(workingTreeChangeCount(events) == 1)

        provider.stopWatching()
        try await Task.sleep(for: .milliseconds(700))
        #expect(workingTreeChangeCount(events) == 1, "停止监听后不得再补发尾随广播")
    }

    // MARK: - Helpers

    private func workingTreeChangeCount(_ events: [GitRepositoryWatchingEvent]) -> Int {
        events.reduce(0) { count, event in
            if case .workingTreeChanged = event { return count + 1 }
            return count
        }
    }

    private func waitUntil(
        timeout: TimeInterval,
        poll: TimeInterval = 0.02,
        _ condition: @MainActor () -> Bool
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            try? await Task.sleep(nanoseconds: UInt64(poll * 1_000_000_000))
        }
        return condition()
    }
}