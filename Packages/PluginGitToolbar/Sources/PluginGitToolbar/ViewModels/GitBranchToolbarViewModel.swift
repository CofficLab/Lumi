import Foundation
import ProviderGit

/// 标题栏分支胶囊的唯一数据来源。
///
/// View 只依赖本 ViewModel；项目切换、仓库状态变化等外部信号由
/// ``GitBranchObserver`` 写入本 ViewModel。
@MainActor
final class GitBranchToolbarViewModel: ObservableObject {
    /// 当前项目路径；`nil` 表示没有打开项目。
    @Published private(set) var projectPath: String?
    /// 当前分支名；`nil` 表示 detached HEAD 或尚未加载。
    @Published private(set) var currentBranch: String?
    /// 可切换的分支列表。
    @Published private(set) var branches: [GitBranchInfo] = []
    /// 当前路径是否为 Git 仓库。非 Git 项目时整个胶囊不显示。
    @Published private(set) var isGitRepository = false
    /// 是否正在执行 Git 写操作（切换 / 新建分支）。
    @Published private(set) var isBusy = false
    /// 最近一次操作失败信息。
    @Published private(set) var errorMessage: String?

    private let capability: any GitBranchCapability
    private var loadTask: Task<Void, Never>?
    /// 加载代次：只有最新一次加载的结果才允许写入状态。
    ///
    /// 仓库 watch 事件可能连续到达（切分支会同时改 HEAD 与 refs），单靠
    /// `Task.isCancelled` 不足以区分「已取消」与「结果已过期」——取消发生在
    /// 挂起点之间时，旧读取仍可能带着旧分支名返回。代次号让过期结果被丢弃。
    private var loadGeneration: UInt64 = 0

    init(capability: any GitBranchCapability) {
        self.capability = capability
    }

    // MARK: - 外部事件写入

    /// 切换当前项目并重新加载分支信息。
    ///
    /// - Parameter path: 新项目路径；`nil` 表示关闭了项目。
    func updateProject(path: String?) {
        guard projectPath != path else { return }
        projectPath = path
        currentBranch = nil
        branches = []
        errorMessage = nil
        isGitRepository = false
        loadTask?.cancel()
        guard let path, !path.isEmpty else { return }
        loadTask = Task { [weak self] in
            guard let self else { return }
            await self.reload(path: path, generation: self.nextGeneration())
        }
    }

    /// 仓库状态变化后重新加载（例如用户在终端里切了分支）。
    func refresh() {
        guard let path = projectPath, !path.isEmpty else { return }
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            await self.reload(path: path, generation: self.nextGeneration())
        }
    }

    // MARK: - 用户操作

    /// 切换到指定分支。
    func switchBranch(to branch: GitBranchInfo) async {
        guard let path = projectPath, !path.isEmpty else { return }
        guard !branch.isRemote else { return }
        guard branch.name != currentBranch else { return }

        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            try await capability.checkout(branch: branch.name, atPath: path)
            await reload(path: path, generation: nextGeneration())
        } catch {
            errorMessage = Self.describe(error)
            await reload(path: path, generation: nextGeneration())
        }
    }

    /// 新建分支并切换过去。
    func createBranch(named name: String) async {
        guard let path = projectPath, !path.isEmpty else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            try await capability.createBranch(named: trimmed, atPath: path)
            await reload(path: path, generation: nextGeneration())
        } catch {
            errorMessage = Self.describe(error)
            await reload(path: path, generation: nextGeneration())
        }
    }

    /// 清除错误提示。
    func dismissError() {
        errorMessage = nil
    }

    // MARK: - 加载

    /// 分配新的加载代次，并让此前所有在途加载作废。
    private func nextGeneration() -> UInt64 {
        loadGeneration &+= 1
        return loadGeneration
    }

    /// 重新加载分支信息。
    ///
    /// - Parameter path: 仓库路径。
    /// - Parameter generation: 本次加载的代次；与当前代次不一致时结果作废。
    private func reload(path: String, generation: UInt64) async {
        let isRepository = await capability.isRepository(atPath: path)
        guard !Task.isCancelled, generation == loadGeneration else { return }
        guard isRepository else {
            isGitRepository = false
            currentBranch = nil
            branches = []
            return
        }

        isGitRepository = true
        do {
            async let current = capability.currentBranch(atPath: path)
            async let list = capability.listBranches(atPath: path, includeRemote: true)
            let (resolvedCurrent, resolvedList) = try await (current, list)
            guard !Task.isCancelled, generation == loadGeneration else { return }
            currentBranch = resolvedCurrent
            branches = Self.sorted(resolvedList)
        } catch {
            guard !Task.isCancelled, generation == loadGeneration else { return }
            currentBranch = nil
            branches = []
            errorMessage = Self.describe(error)
        }
    }

    /// 本地分支在前、当前分支置顶，其余按名称排序。
    private static func sorted(_ branches: [GitBranchInfo]) -> [GitBranchInfo] {
        branches.sorted { lhs, rhs in
            if lhs.isCurrent != rhs.isCurrent { return lhs.isCurrent }
            if lhs.isRemote != rhs.isRemote { return !lhs.isRemote }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private static func describe(_ error: any Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
