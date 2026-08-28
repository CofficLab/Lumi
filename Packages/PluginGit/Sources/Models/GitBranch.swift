import Foundation

public enum GitError: LocalizedError {
    case notGitRepository, checkoutFailed(String), createBranchFailed(String), fetchFailed(String), dirtyWorkingTree, invalidBranchName(String), unknown(String)
    public var errorDescription: String? {
        switch self {
        case .notGitRepository: "Not a Git Repository"
        case .checkoutFailed(let message): "Checkout Failed: \(message)"
        case .createBranchFailed(let message): "Create Branch Failed: \(message)"
        case .fetchFailed(let message): "Fetch Failed: \(message)"
        case .dirtyWorkingTree: "Working tree has uncommitted changes"
        case .invalidBranchName(let message): "Invalid Branch Name: \(message)"
        case .unknown(let message): message
        }
    }
}
