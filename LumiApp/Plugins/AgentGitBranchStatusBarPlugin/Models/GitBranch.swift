import Foundation

/// Git 操作错误类型
enum GitError: LocalizedError {
    case notGitRepository
    case checkoutFailed(String)
    case createBranchFailed(String)
    case fetchFailed(String)
    case dirtyWorkingTree
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .notGitRepository:
            return String(localized: "Not a Git Repository", table: "GitBranchStatusBar")
        case .checkoutFailed(let msg):
            return String(localized: "Checkout Failed: ", table: "GitBranchStatusBar") + msg
        case .createBranchFailed(let msg):
            return String(localized: "Create Branch Failed: ", table: "GitBranchStatusBar") + msg
        case .fetchFailed(let msg):
            return String(localized: "Fetch Failed: ", table: "GitBranchStatusBar") + msg
        case .dirtyWorkingTree:
            return String(localized: "Working tree has uncommitted changes", table: "GitBranchStatusBar")
        case .unknown(let msg):
            return msg
        }
    }
}

/// Git 分支模型
struct GitBranch: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let isCurrent: Bool
    let isRemote: Bool
    let lastCommitSubject: String?
    let lastCommitDate: Date?

    /// 显示名称（远程分支去掉 origin/ 前缀）
    var displayName: String {
        if isRemote, let range = name.range(of: "/") {
            return String(name[range.upperBound...])
        }
        return name
    }

    /// 远程名称（如 origin）
    var remoteName: String? {
        guard isRemote, let range = name.range(of: "/") else { return nil }
        return String(name[..<range.lowerBound])
    }
}
