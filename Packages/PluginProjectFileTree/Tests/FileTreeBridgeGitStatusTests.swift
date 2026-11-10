import Foundation
import Testing

@testable import PluginProjectFileTree

/// 回归 #1098：新 Git 快照只赋值不重载可见行，已显示的状态标记会停留在旧值。
@MainActor
@Test("新的 Git 快照令牌会重载可见行")
func newGitStatusTokenUpdatesVisibleRows() {
    let coordinator = FileTreeNSViewBridge.Coordinator()
    let viewController = RecordingGitStatusView()

    coordinator.lastGitStatusToken = 0
    coordinator.applyGitStatus(.empty, token: 0, to: viewController)
    #expect(viewController.snapshots.isEmpty)

    let snapshot = GitStatusSnapshot(
        entriesByRelativePath: ["Sources/A.swift": GitStatusEntry(relativePath: "Sources/A.swift", status: .modified)],
        directoryAggregateByRelativePath: ["Sources": .modified],
        repoRootPath: "/tmp/Project",
        capturedAt: Date()
    )
    coordinator.applyGitStatus(snapshot, token: 1, to: viewController)

    #expect(viewController.snapshots.count == 1)
    #expect(viewController.snapshots.last == snapshot)
}

@MainActor
@Test("相同 Git 状态令牌不会重复重载")
func repeatedGitStatusTokenDoesNotReload() {
    let coordinator = FileTreeNSViewBridge.Coordinator()
    let viewController = RecordingGitStatusView()

    coordinator.applyGitStatus(.empty, token: 1, to: viewController)
    coordinator.applyGitStatus(.empty, token: 1, to: viewController)

    #expect(viewController.snapshots.count == 1)
}

@MainActor
private final class RecordingGitStatusView: FileTreeGitStatusUpdating {
    private(set) var snapshots: [GitStatusSnapshot] = []

    func updateGitStatus(_ snapshot: GitStatusSnapshot) {
        snapshots.append(snapshot)
    }
}
