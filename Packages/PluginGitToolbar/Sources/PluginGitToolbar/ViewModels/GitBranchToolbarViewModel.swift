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
            await self?.reload(path: path)
        }
    }

    /// 仓库状态变化后重新加载（例如用户在终端里切了分支）。
    func refresh() {
        guard let path = projectPath, !path.isEmpty else { return }
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            await self?.reload(path: path)
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
            await reload(path: path)
        } catch {
            errorMessage = Self.describe(error)
            await reload(path: path)
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
            await reload(path: path)
        } catch {
            errorMessage = Self.describe(error)
            await reload(path: path)
        }
    }

    /// 清除错误提示。
    func dismissError() {
        errorMessage = nil
    }

    // MARK: - 加载

    private func reload(path: String) async {
        let isRepository = await capability.isRepository(atPath: path)
        guard !Task.isCancelled else { return }
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
            guard !Task.isCancelled else { return }
            currentBranch = resolvedCurrent
            branches = Self.sorted(resolvedList)
        } catch {
            guard !Task.isCancelled else { return }
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
