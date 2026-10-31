import Foundation
import ProviderGit

/// Chat Toolbar 面板的唯一数据来源。
///
/// 所有外部事件写入均由 ``GitChatObserver`` 触发（`updateProjectPath` /
/// `reloadAll` / `resetForMissingWatch`）。ViewModel 通过 ``GitChatCapability``
/// 读取数据，不直接持有 `any GitRepositoryReading`。
///
/// ## 刷新节流
///
/// 多个仓库事件可能在短时间内连续触发（工作区文件连续变更、外部 `git commit`
/// 同时触发 headChanged 与 indexChanged）。ViewModel 用 generation token
/// 丢弃迟到结果，并用 `Task.sleep` 做 1 秒去抖，保证快速连发的事件只产生
/// 一次实际 libgit2 调用。
@MainActor
public final class GitChatToolbarViewModel: ObservableObject {
    // MARK: - Published State

    @Published public private(set) var projectPath: String?
    @Published public private(set) var isGitRepository: Bool = false
    @Published public private(set) var status: GitStatus?
    @Published public private(set) var commits: [GitCommitLog] = []
    @Published public private(set) var selectedCommitHash: String?
    @Published public private(set) var selectedCommitChanges: [GitCommitChange] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var isLoadingCommitChanges = false
    @Published public private(set) var errorMessage: String?

    // MARK: - Internals

    private weak var capability: (any GitChatCapability)?
    private weak var projectCapability: (any GitChatProjectCapability)?
    private var reloadGeneration: UInt64 = 0
    private var reloadTask: Task<Void, Never>?

    public init(
        capability: (any GitChatCapability)?,
        projectCapability: (any GitChatProjectCapability)? = nil
    ) {
        self.capability = capability
        self.projectCapability = projectCapability
    }

    // MARK: - Derived

    /// 工作区变更项列表（已合成 staged/未暂存 标记与状态枚举）。
    public var workingChanges: [GitWorkingChange] {
        status?.workingChanges() ?? []
    }

    /// 当前显示的 commit 列表的变更文件（选中 commit 时）。
    public var visibleCommitChanges: [GitCommitChange] {
        selectedCommitChanges
    }

    /// 当前分支名（工作区状态里的 branch）。
    public var branchName: String {
        let branch = status?.branch.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return branch.isEmpty ? "HEAD" : branch
    }

    /// 仓库根路径（用于展示与拼接文件绝对路径）。
    public var repositoryPath: String? {
        projectPath
    }

    // MARK: - External Events

    /// 切换当前项目路径（观察者触发）。
    public func updateProjectPath(_ path: String?) {
        guard projectPath != path else { return }
        projectPath = path
        // 项目切换：清空所有状态后立即重新加载（首次无去抖，后续事件才有 1s 去抖）。
        status = nil
        commits = []
        selectedCommitHash = nil
        selectedCommitChanges = []
        errorMessage = nil
        isLoading = false
        guard path != nil else {
            isGitRepository = false
            return
        }
        refreshNow()
    }

    /// 仓库 watch 停止时清空数据（项目被 close 等场景）。
    public func resetForMissingWatch() {
        status = nil
        commits = []
        selectedCommitHash = nil
        selectedCommitChanges = []
        errorMessage = nil
    }

    /// 触发整表重载（含 1 秒去抖）。
    public func reloadAll() {
        reloadGeneration &+= 1
        let generation = reloadGeneration
        reloadTask?.cancel()
        reloadTask = Task { [weak self] in
            // 去抖 1 秒，合并短时间内的多次刷新请求。
            do { try await Task.sleep(nanoseconds: 1_000_000_000) }
            catch { return }
            guard let self, self.reloadGeneration == generation else { return }
            await self.performReload(generation: generation)
        }
    }

    /// 选中某个 commit 后加载其变更文件。
    public func selectCommit(hash: String) {
        guard selectedCommitHash != hash else { return }
        selectedCommitHash = hash
        selectedCommitChanges = []
        isLoadingCommitChanges = true
        errorMessage = nil

        guard let capability, let path = projectPath else {
            isLoadingCommitChanges = false
            return
        }

        Task {
            do {
                let changes = try await capability.commitChanges(atPath: path, hash: hash)
                guard self.selectedCommitHash == hash else { return }
                self.selectedCommitChanges = changes
            } catch {
                guard self.selectedCommitHash == hash else { return }
                self.errorMessage = Self.describe(error)
            }
            self.isLoadingCommitChanges = false
        }
    }

    /// 清除 commit 选中状态。
    public func clearCommitSelection() {
        selectedCommitHash = nil
        selectedCommitChanges = []
        isLoadingCommitChanges = false
    }

    /// 立即触发刷新（跳过 1 秒去抖，用于「刷新」按钮）。
    public func refreshNow() {
        reloadGeneration &+= 1
        let generation = reloadGeneration
        reloadTask?.cancel()
        reloadTask = Task { [weak self] in
            guard let self else { return }
            await self.performReload(generation: generation)
        }
    }

    /// 点击工作区文件：以预览方式切到该文件（第一版只读，不打开编辑器）。
    ///
    /// 相对路径来自 ``GitStatus/workingChanges()``，与仓库根目录拼接后
    /// 交给项目能力，由宿主决定如何呈现。
    public func previewWorkingChange(path relativePath: String) {
        guard let projectCapability, let repositoryPath, !repositoryPath.isEmpty else { return }
        projectCapability.previewFile(inRepositoryAt: repositoryPath, relativePath: relativePath)
    }

    // MARK: - Reload

    private func performReload(generation: UInt64) async {
        guard let capability, let path = projectPath, !path.isEmpty else {
            isGitRepository = false
            status = nil
            commits = []
            errorMessage = nil
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        // 并行读取：isRepository + status + 最近 50 commits。
        async let isRepo = capability.isRepository(atPath: path)
        async let loadedStatus = loadStatusOrError(capability: capability, path: path)
        async let loadedCommits = loadCommitsOrError(capability: capability, path: path)

        let (repo, statusResult, commitsResult) = await (isRepo, loadedStatus, loadedCommits)

        // 过期请求直接丢弃（期间可能又触发了刷新）。
        guard self.reloadGeneration == generation else { return }

        isGitRepository = repo
        switch statusResult {
        case .success(let value): status = value
        case .failure(let error):
            status = nil
            errorMessage = Self.describe(error)
        }
        switch commitsResult {
        case .success(let value): commits = value
        case .failure(let error):
            commits = []
            if errorMessage == nil { errorMessage = Self.describe(error) }
        }
        isLoading = false
    }

    private func loadStatusOrError(
        capability: any GitChatCapability,
        path: String
    ) async -> Result<GitStatus?, Error> {
        await Result { try await capability.status(atPath: path) }
    }

    private func loadCommitsOrError(
        capability: any GitChatCapability,
        path: String
    ) async -> Result<[GitCommitLog], Error> {
        await Result { try await capability.log(atPath: path, count: 50, skip: 0) }
    }

    // MARK: - Helpers

    private static func describe(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
