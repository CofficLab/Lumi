import Foundation
import LibGit2Swift

/// Git 分支操作服务（基于 LibGit2Swift 原生实现）
public enum GitBranchService {
    // MARK: - 分支查询

    /// 获取当前分支名
    public static func currentBranch(at path: String) -> String? {
        try? LibGit2.getCurrentBranch(at: path)
    }

    /// 获取所有本地分支
    public static func listLocalBranches(at path: String) -> [GitBranch] {
        (try? LibGit2.getBranchList(at: path, includeRemote: false)) ?? []
    }

    /// 获取所有远程分支
    public static func listRemoteBranches(at path: String) -> [GitBranch] {
        (try? LibGit2.getRemoteBranches(at: path)) ?? []
    }

    // MARK: - 分支操作

    /// 切换到指定分支
    public static func checkout(branch: String, at path: String) throws {
        try LibGit2.checkout(branch: branch, at: path)
    }

    /// 创建新分支并切换
    public static func createBranch(_ name: String, at path: String) throws {
        try validateBranchName(name)
        try LibGit2.checkoutNewBranch(named: name, at: path)
    }

    public static func validateBranchName(_ name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed == name, !name.isEmpty else {
            throw GitError.invalidBranchName("Enter a branch name without leading or trailing whitespace.")
        }
        guard name != "@" else {
            throw GitError.invalidBranchName("Branch name cannot be @.")
        }
        guard !name.hasPrefix("-") else {
            throw GitError.invalidBranchName("Branch name cannot start with a dash.")
        }
        guard !name.hasPrefix("/") && !name.hasSuffix("/") && !name.contains("//") else {
            throw GitError.invalidBranchName("Branch name cannot start, end, or repeat /.")
        }
        guard !name.hasSuffix(".") && !name.contains("..") && !name.contains("@{") else {
            throw GitError.invalidBranchName("Branch name contains a reserved Git sequence.")
        }

        let forbiddenScalars = CharacterSet(charactersIn: " ~^:?*[\\")
            .union(.controlCharacters)
        guard name.unicodeScalars.allSatisfy({ !forbiddenScalars.contains($0) }) else {
            throw GitError.invalidBranchName("Branch name contains characters Git does not allow.")
        }

        let components = name.split(separator: "/", omittingEmptySubsequences: false)
        guard components.allSatisfy({ !$0.hasPrefix(".") && !$0.hasSuffix(".lock") }) else {
            throw GitError.invalidBranchName("Branch path components cannot start with . or end with .lock.")
        }
    }

    // MARK: - 工作区状态

    /// 检查工作区是否有未提交的更改
    public static func isWorkingTreeDirty(at path: String) -> Bool {
        (try? LibGit2.hasUncommittedChanges(at: path, verbose: false)) ?? false
    }
}
