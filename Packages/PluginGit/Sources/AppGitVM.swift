import Foundation

/// Shared Git panel selection state for commit history and detail views.
@MainActor
public final class AppGitVM: ObservableObject {
    @Published public private(set) var selectedCommitHash: String?
    private var unpushedCommitHashes = Set<String>()

    public init() {}

    public func selectCommit(hash: String?) {
        selectedCommitHash = hash
    }

    public func clearSelection() {
        selectedCommitHash = nil
    }

    public func isCommitUnpushed(_ hash: String) -> Bool {
        unpushedCommitHashes.contains(hash)
    }

    public func updateUnpushedCommitHashes(_ hashes: [String]) {
        unpushedCommitHashes = Set(hashes)
    }

    public func clearUnpushedCommits() {
        unpushedCommitHashes.removeAll()
    }
}
