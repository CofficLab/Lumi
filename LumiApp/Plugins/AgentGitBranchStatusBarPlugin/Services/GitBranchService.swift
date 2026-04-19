import Foundation
import LibGit2Swift

/// Git 分支操作服务（基于 LibGit2Swift 原生实现）
enum GitBranchService {
    // MARK: - 分支查询

    /// 获取当前分支名
    static func currentBranch(at path: String) -> String? {
        try? LibGit2.getCurrentBranch(at: path)
    }

    /// 获取所有本地分支
    static func listLocalBranches(at path: String) -> [GitBranch] {
        (try? LibGit2.getBranchList(at: path, includeRemote: false)) ?? []
    }

    /// 获取所有远程分支
    static func listRemoteBranches(at path: String) -> [GitBranch] {
        (try? LibGit2.getRemoteBranches(at: path)) ?? []
    }

    // MARK: - 分支操作

    /// 切换到指定分支
    static func checkout(branch: String, at path: String) throws {
        try LibGit2.checkout(branch: branch, at: path)
    }

    /// 创建新分支并切换
    static func createBranch(_ name: String, at path: String) throws {
        try LibGit2.checkoutNewBranch(named: name, at: path)
    }

    // MARK: - 工作区状态

    /// 检查工作区是否有未提交的更改
    static func isWorkingTreeDirty(at path: String) -> Bool {
        (try? LibGit2.hasUncommittedChanges(at: path, verbose: false)) ?? false
    }
}
