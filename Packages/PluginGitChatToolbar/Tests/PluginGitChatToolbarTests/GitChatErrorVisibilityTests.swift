import Foundation
import Testing
import ProviderGit
@testable import PluginGitChatToolbar

/// 回归 #390：部分读取失败必须始终可见，不能被「工作区干净 / 0 文件」等正常空态掩盖。
///
/// 错误横幅原先要求 workingChanges 与 commits 同时为空才展示；status 失败但 commits
/// 成功、或选中 commit 的 diff 失败时，错误被非空列表掩盖。修复后只要 errorMessage
/// 非空就展示横幅（`shouldShowErrorBanner`）。
@MainActor
@Suite("GitChat 错误可见性（回归 #390）", .serialized)
struct GitChatErrorVisibilityTests {

    private func makeCommit(hash: String) -> GitCommitLog {
        GitCommitLog(hash: hash, author: "n", email: "e", date: "2026-09-16T00:00:00Z", message: "m")
    }

    @Test("status 读取失败时即使有提交也必须展示错误")
    func statusReadErrorStaysVisibleWithCommits() async throws {
        let git = InMemoryGitRepositoryReading()
        git.addRepository(atPath: "/repo")
        // 只设置 commits，不设置 status：status 读取抛错，commits 读取成功。
        git.setCommits([makeCommit(hash: "abc")], forPath: "/repo")

        // capability 由 ViewModel 弱引用持有，必须用局部强引用保活到测试结束。
        let capability = GitChatCapabilityAdapter(provider: git)
        let vm = GitChatToolbarViewModel(capability: capability)
        vm.updateProjectPath("/repo")
        await waitForLoad()

        // status 失败：工作区状态未知（0 变更），但提交列表非空。
        #expect(vm.errorMessage != nil)
        #expect(vm.workingChangeCount == 0)
        #expect(vm.commits.count == 1)
        // 关键回归：错误必须可见，不得被非空提交列表掩盖成「工作区干净」。
        #expect(vm.shouldShowErrorBanner)
    }

    @Test("commit diff 读取失败必须展示错误而非 0 文件")
    func commitDiffErrorStaysVisible() async throws {
        let git = InMemoryGitRepositoryReading()
        git.addRepository(atPath: "/repo")
        git.setStatus(GitStatus(branch: "main"), forPath: "/repo")
        git.setCommits([makeCommit(hash: "abc")], forPath: "/repo")
        // 不设置该 commit 的变更文件：commitChanges 读取抛错。

        let capability = GitChatCapabilityAdapter(provider: git)
        let vm = GitChatToolbarViewModel(capability: capability)
        vm.updateProjectPath("/repo")
        await waitForLoad()
        #expect(vm.errorMessage == nil)

        vm.selectCommit(hash: "abc")
        await waitForLoad()

        #expect(vm.selectedCommitHash == "abc")
        #expect(vm.selectedCommitChanges.isEmpty)
        #expect(vm.errorMessage != nil)
        // 关键回归：diff 失败必须可见，不得伪装成「0 文件」。
        #expect(vm.shouldShowErrorBanner)
    }

    @Test("工作区干净且无错误时不展示错误横幅")
    func cleanStateDoesNotShowErrorBanner() async throws {
        let git = InMemoryGitRepositoryReading()
        git.addRepository(atPath: "/repo")
        git.setStatus(GitStatus(branch: "main"), forPath: "/repo")
        git.setCommits([makeCommit(hash: "abc")], forPath: "/repo")

        let capability = GitChatCapabilityAdapter(provider: git)
        let vm = GitChatToolbarViewModel(capability: capability)
        vm.updateProjectPath("/repo")
        await waitForLoad()

        #expect(vm.errorMessage == nil)
        #expect(vm.workingChangeCount == 0)
        #expect(vm.commits.count == 1)
        // 正常空态不得误报错误。
        #expect(vm.shouldShowErrorBanner == false)
    }
}

/// 等待 ViewModel 完成异步加载（与既有测试一致）。
@MainActor
private func waitForLoad() async {
    for _ in 0..<5 {
        await Task.yield()
        try? await Task.sleep(nanoseconds: 20_000_000)
    }
}