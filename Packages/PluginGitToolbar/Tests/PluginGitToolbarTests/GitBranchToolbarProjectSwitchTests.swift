import Foundation
import ProviderGit
import ProviderGitRepositoryWatch
import Testing
@testable import PluginGitToolbar

/// 项目切换后，旧项目里发起的分支写操作不得把结果写回新项目的胶囊（回归 #214）。
///
/// `switchBranch` / `createBranch` 在 await 之前捕获 `path`，await 之后无条件
/// `reload(path:generation: nextGeneration())`。`nextGeneration()` 把自己变成最新代次，
/// 于是即便用户已切到 B，A 的迟到结果仍「合法地」覆盖 B 的分支名与分支列表。
/// 修复：post-operation 写回前复核捕获的 path 仍等于当前 `projectPath`。
@MainActor
@Suite("Git branch toolbar project switch")
struct GitBranchToolbarProjectSwitchTests {

    /// checkout / createBranch 可被挂起的替身：用于在写操作进行中切换项目。
    @MainActor
    private final class GatedBranchCapability: GitBranchCapability, @unchecked Sendable {
        private let base: GitBranchCapabilityAdapter
        private var gate: CheckedContinuation<Void, Never>?
        private(set) var operationStarted = false
        var holdOperations = false

        init(git: InMemoryGitBranchManaging) {
            base = GitBranchCapabilityAdapter(provider: git)
        }

        func isRepository(atPath path: String) async -> Bool {
            await base.isRepository(atPath: path)
        }

        func currentBranch(atPath path: String) async throws -> String? {
            try await base.currentBranch(atPath: path)
        }

        func detachedHeadCommitHash(atPath path: String) async throws -> String? {
            try await base.detachedHeadCommitHash(atPath: path)
        }

        func listBranches(atPath path: String, includeRemote: Bool) async throws -> [GitBranchInfo] {
            try await base.listBranches(atPath: path, includeRemote: includeRemote)
        }

        func checkout(branch: String, atPath path: String) async throws {
            await waitIfHeld()
            try await base.checkout(branch: branch, atPath: path)
        }

        func createBranch(named name: String, atPath path: String) async throws {
            await waitIfHeld()
            try await base.createBranch(named: name, atPath: path)
        }

        func addRepositoryObserver(
            _ callback: @escaping (GitRepositoryWatchingEvent) -> Void
        ) -> (any GitRepositoryWatchingObserverHandle)? {
            base.addRepositoryObserver(callback)
        }

        private func waitIfHeld() async {
            guard holdOperations else { return }
            operationStarted = true
            await withCheckedContinuation { continuation in
                gate = continuation
            }
        }

        func release() {
            gate?.resume()
            gate = nil
        }
    }

    private func makeGit() -> InMemoryGitBranchManaging {
        let git = InMemoryGitBranchManaging()
        git.addRepository(atPath: "/tmp/repoA")
        git.setCurrentBranch("main", forPath: "/tmp/repoA")
        git.setBranches(
            [
                GitBranchInfo(name: "main", isCurrent: true),
                GitBranchInfo(name: "feature", isCurrent: false),
            ],
            forPath: "/tmp/repoA"
        )
        git.addRepository(atPath: "/tmp/repoB")
        git.setCurrentBranch("trunk", forPath: "/tmp/repoB")
        git.setBranches([GitBranchInfo(name: "trunk", isCurrent: true)], forPath: "/tmp/repoB")
        return git
    }

    private func waitUntilStarted(_ capability: GatedBranchCapability) async throws {
        for _ in 0..<200 {
            if capability.operationStarted { return }
            try await Task.sleep(for: .milliseconds(5))
        }
    }

    @Test("切到 B 后，A 的迟到 checkout 结果不覆盖 B 的分支胶囊（回归 #214）")
    func staleCheckoutDoesNotOverwriteNewProject() async throws {
        let git = makeGit()
        let capability = GatedBranchCapability(git: git)
        let viewModel = GitBranchToolbarViewModel(capability: capability)

        viewModel.updateProject(path: "/tmp/repoA")
        try await Task.sleep(for: .milliseconds(100))
        #expect(viewModel.currentBranch == "main")

        let feature = try #require(viewModel.branches.first { $0.name == "feature" })
        capability.holdOperations = true
        let operation = Task { @MainActor in await viewModel.switchBranch(to: feature) }
        try await waitUntilStarted(capability)

        // 写操作仍在途时切到 B，B 的分支信息加载完成。
        viewModel.updateProject(path: "/tmp/repoB")
        try await Task.sleep(for: .milliseconds(100))
        #expect(viewModel.projectPath == "/tmp/repoB")
        #expect(viewModel.currentBranch == "trunk")

        // 放行 A 的 checkout：其迟到结果不得写回 B。
        capability.release()
        await operation.value
        try await Task.sleep(for: .milliseconds(100))

        #expect(viewModel.projectPath == "/tmp/repoB")
        #expect(viewModel.currentBranch == "trunk")
        #expect(viewModel.branches.contains { $0.name == "trunk" })
        #expect(!viewModel.branches.contains { $0.name == "feature" })
    }

    @Test("切到 B 后，A 的迟到 createBranch 结果不覆盖 B 的分支胶囊（回归 #214）")
    func staleCreateBranchDoesNotOverwriteNewProject() async throws {
        let git = makeGit()
        let capability = GatedBranchCapability(git: git)
        let viewModel = GitBranchToolbarViewModel(capability: capability)

        viewModel.updateProject(path: "/tmp/repoA")
        try await Task.sleep(for: .milliseconds(100))
        #expect(viewModel.currentBranch == "main")

        capability.holdOperations = true
        let operation = Task { @MainActor in await viewModel.createBranch(named: "feature/new") }
        try await waitUntilStarted(capability)

        viewModel.updateProject(path: "/tmp/repoB")
        try await Task.sleep(for: .milliseconds(100))
        #expect(viewModel.projectPath == "/tmp/repoB")
        #expect(viewModel.currentBranch == "trunk")

        capability.release()
        await operation.value
        try await Task.sleep(for: .milliseconds(100))

        #expect(viewModel.projectPath == "/tmp/repoB")
        #expect(viewModel.currentBranch == "trunk")
        #expect(!viewModel.branches.contains { $0.name == "feature/new" })
    }
}