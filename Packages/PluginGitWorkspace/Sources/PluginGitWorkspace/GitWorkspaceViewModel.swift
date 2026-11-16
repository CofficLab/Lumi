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
    @Published private(set) var status: GitStatus? {
        didSet { rebuildWorkingTree() }
    }
    @Published private(set) var commits: [GitCommitLog] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let git: any GitWorkspaceGitProviding
    private var requestGeneration = 0
    private var loadingPath: String?

    /// 缓存的工作树文件列表（去重 + 排序），仅在 status 变化时重建。
    /// 视图每次 body 会多次读取它，避免每次都重建 Set 并排序（见 issue #1283）。
    @Published private(set) var workingTreeFiles: [String] = []
    /// 文件 → 变更标签的预计算映射，让 changeLabel 从 O(N) 线性扫描降为 O(1)。
    private var changeLabels: [String: String] = [:]

    init(git: any GitWorkspaceGitProviding) {
        self.git = git
    }

    func changeLabel(for file: String) -> String {
        changeLabels[file] ?? "?"
    }

    /// status 变化时一次性重建工作树列表与标签映射。
    ///
    /// 标签优先级与原先的逐个 `contains` 判断一致：
    /// staged(S) > added(A) > deleted(D) > renamed(R) > untracked(?) > modified(M)。
    /// 按优先级从低到高写入字典，高优先级覆盖低优先级。
    private func rebuildWorkingTree() {
        guard let status else {
            workingTreeFiles = []
            changeLabels = [:]
            return
        }
        let all = status.modified + status.added + status.deleted
            + status.renamed + status.staged + status.untracked
        workingTreeFiles = Array(Set(all)).sorted()

        var labels: [String: String] = [:]
        for file in status.modified { labels[file] = "M" }
        for file in status.untracked { labels[file] = "?" }
        for file in status.renamed { labels[file] = "R" }
        for file in status.deleted { labels[file] = "D" }
        for file in status.added { labels[file] = "A" }
        for file in status.staged { labels[file] = "S" }
        changeLabels = labels
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
