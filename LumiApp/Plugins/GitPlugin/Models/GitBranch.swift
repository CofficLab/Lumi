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
            return String(localized: "Not a Git Repository", table: "GitPlugin")
        case .checkoutFailed(let msg):
            return String(localized: "Checkout Failed: ", table: "GitPlugin") + msg
        case .createBranchFailed(let msg):
            return String(localized: "Create Branch Failed: ", table: "GitPlugin") + msg
        case .fetchFailed(let msg):
            return String(localized: "Fetch Failed: ", table: "GitPlugin") + msg
        case .dirtyWorkingTree:
            return String(localized: "Working tree has uncommitted changes", table: "GitPlugin")
        case .unknown(let msg):
            return msg
        }
    }
}
