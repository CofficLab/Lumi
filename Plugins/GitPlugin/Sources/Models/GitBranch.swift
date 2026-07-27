import Foundation
import LumiKernel

/// Git 操作错误类型
public enum GitError: LocalizedError {
    case notGitRepository
    case checkoutFailed(String)
    case createBranchFailed(String)
    case fetchFailed(String)
    case dirtyWorkingTree
    case invalidBranchName(String)
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .notGitRepository:
            return LumiPluginLocalization.string("Not a Git Repository", bundle: .module)
        case .checkoutFailed(let msg):
            return LumiPluginLocalization.string("Checkout Failed: ", bundle: .module) + msg
        case .createBranchFailed(let msg):
            return LumiPluginLocalization.string("Create Branch Failed: ", bundle: .module) + msg
        case .fetchFailed(let msg):
            return LumiPluginLocalization.string("Fetch Failed: ", bundle: .module) + msg
        case .dirtyWorkingTree:
            return LumiPluginLocalization.string("Working tree has uncommitted changes", bundle: .module)
        case .invalidBranchName(let msg):
            return LumiPluginLocalization.string("Invalid Branch Name: ", bundle: .module) + msg
        case .unknown(let msg):
            return msg
        }
    }
}
