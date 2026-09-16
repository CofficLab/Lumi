import Combine
import Foundation
import ProviderGit

protocol GitWorkspaceGitProviding: Sendable {
    func getStatus(path: String) async throws -> GitStatus
    func getLog(path: String, count: Int, branch: String?, file: String?) async throws -> [GitCommitLog]
}

/// 把 `GitRepositoryReading` 契约适配为本模块内部的窄协议。
///
/// 插件不得依赖 `PluginGit`，Git 数据统一来自 ProviderGit 契约。
struct ContractGitWorkspaceGitProvider: GitWorkspaceGitProviding {
    let git: any GitRepositoryReading

    func getStatus(path: String) async throws -> GitStatus {
        try await git.status(atPath: path)
    }

    func getLog(path: String, count: Int, branch: String?, file: String?) async throws -> [GitCommitLog] {
        try await git.log(atPath: path, count: count, branch: branch, file: file)
    }
}

/// 宿主未装配 `PluginGit` 时的降级实现：面板照常渲染，操作返回明确错误。
struct UnavailableGitWorkspaceGitProvider: GitWorkspaceGitProviding {
    func getStatus(path: String) async throws -> GitStatus {
        throw GitReadError.repositoryNotFound(path: path)
    }

    func getLog(path: String, count: Int, branch: String?, file: String?) async throws -> [GitCommitLog] {
        throw GitReadError.repositoryNotFound(path: path)
    }
}

@MainActor
final class GitWorkspaceViewModel: ObservableObject {
    @Published private(set) var status: GitStatus?
    @Published private(set) var commits: [GitCommitLog] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let git: any GitWorkspaceGitProviding
    private var requestGeneration = 0
    private var loadingPath: String?

    var workingTreeFiles: [String] {
        guard let status else { return [] }
        return Array(Set(status.modified + status.added + status.deleted + status.renamed + status.staged)).sorted()
    }

    init(git: any GitWorkspaceGitProviding) {
        self.git = git
    }

    func changeLabel(for file: String) -> String {
        guard let status else { return "?" }
        if status.staged.contains(file) { return "S" }
        if status.added.contains(file) { return "A" }
        if status.deleted.contains(file) { return "D" }
        if status.renamed.contains(file) { return "R" }
        return "M"
    }

    func reload(path: String?, force: Bool = false) async {
        guard let path, !path.isEmpty else {
            requestGeneration += 1
            loadingPath = nil
            status = nil
            commits = []
            errorMessage = nil
            isLoading = false
            return
        }

        if isLoading, loadingPath == path, !force { return }

        requestGeneration += 1
        let generation = requestGeneration
        loadingPath = path
        isLoading = true
        errorMessage = nil

        do {
            async let loadedStatus = git.getStatus(path: path)
            async let loadedCommits = git.getLog(path: path, count: 50, branch: nil, file: nil)
            let resolvedStatus = try await loadedStatus
            guard generation == requestGeneration else { return }
            status = resolvedStatus
            let resolvedCommits = try await loadedCommits
            guard generation == requestGeneration else { return }
            commits = resolvedCommits
        } catch {
            guard generation == requestGeneration else { return }
            errorMessage = error.localizedDescription
        }

        guard generation == requestGeneration else { return }
        isLoading = false
        loadingPath = nil
    }
}
