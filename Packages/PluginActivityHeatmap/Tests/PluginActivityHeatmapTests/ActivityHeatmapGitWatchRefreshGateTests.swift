import Foundation
import ProviderGitRepositoryWatch
import Testing

@testable import PluginActivityHeatmap

/// 提交活动热图对 Git 监听事件的刷新门控（#505）。
///
/// 切到已存在的分支只改 HEAD 符号引用、refs 不变，监听器只发 `.headChanged`；
/// 旧实现仅接受 `.refsChanged`，导致项目 Commit Activity 停留在旧分支提交。
/// 门控须在 HEAD 变化时刷新，同时忽略不影响提交历史的事件以免无谓重算。
@Suite("Activity heatmap git-watch refresh gate")
@MainActor
struct ActivityHeatmapGitWatchRefreshGateTests {
    @Test("HEAD change refreshes commit activity, even when the commit hash is unchanged")
    func headChangeRefreshesCommitActivity() {
        #expect(ActivityHeatmapPlugin.shouldRefreshCommitActivity(
            for: .headChanged(previousHead: "old", head: "new")
        ))
        // 同 commit 切换分支：hash 不变但 headRef 变，监听器仍发 headChanged。
        #expect(ActivityHeatmapPlugin.shouldRefreshCommitActivity(
            for: .headChanged(previousHead: "same", head: "same")
        ))
        #expect(ActivityHeatmapPlugin.shouldRefreshCommitActivity(
            for: .headChanged(previousHead: nil, head: nil)
        ))
    }

    @Test("refs change still refreshes commit activity")
    func refsChangeRefreshesCommitActivity() {
        #expect(ActivityHeatmapPlugin.shouldRefreshCommitActivity(for: .refsChanged))
    }

    @Test("events that do not alter commit history do not refresh")
    func nonHistoryEventsDoNotRefresh() {
        #expect(!ActivityHeatmapPlugin.shouldRefreshCommitActivity(for: .indexChanged))
        #expect(!ActivityHeatmapPlugin.shouldRefreshCommitActivity(for: .stashChanged))
        #expect(!ActivityHeatmapPlugin.shouldRefreshCommitActivity(for: .workingTreeChanged))
        #expect(!ActivityHeatmapPlugin.shouldRefreshCommitActivity(
            for: .started(repositoryURL: URL(fileURLWithPath: "/tmp/repo"))
        ))
        #expect(!ActivityHeatmapPlugin.shouldRefreshCommitActivity(for: .stopped))
    }
}