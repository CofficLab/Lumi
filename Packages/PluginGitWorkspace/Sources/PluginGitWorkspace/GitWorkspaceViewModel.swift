import Combine
import Foundation
import GitPlugin

protocol GitWorkspaceGitProviding: Sendable {
    func getStatus(path: String) async throws -> GitStatus
    func getLog(path: String, count: Int, branch: String?, file: String?) async throws -> [GitCommitLog]
}

struct LiveGitWorkspaceGitProvider: GitWorkspaceGitProviding {
    func getStatus(path: String) async throws -> GitStatus {
        try await GitService.shared.getStatus(path: path)
    }

    func getLog(path: String, count: Int, branch: String?, file: String?) async throws -> [GitCommitLog] {
        try await GitService.shared.getLog(path: path, count: count, branch: branch, file: file)
    }
}

@MainActor
final class GitWorkspaceViewModel: ObservableObject {
    @Published private(set) var status: GitStatus?
    @Published private(set) var commits: [GitCommitLog] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let git: any GitWorkspaceGitProviding
    private var requestGeneration = 0
    private var loadingPath: String?

    var workingTreeFiles: [String] {
        guard let status else { return [] }
        return Array(Set(status.modified + status.added + status.deleted + status.renamed + status.staged)).sorted()
    }

    init(git: any GitWorkspaceGitProviding) {
        self.git = git
    }

    func changeLabel(for file: String) -> String {
        guard let status else { return "?" }
        if status.staged.contains(file) { return "S" }
        if status.added.contains(file) { return "A" }
        if status.deleted.contains(file) { return "D" }
        if status.renamed.contains(file) { return "R" }
        return "M"
    }

    func reload(path: String?, force: Bool = false) async {
        guard let path, !path.isEmpty else {
            requestGeneration += 1
            loadingPath = nil
            status = nil
            commits = []
            errorMessage = nil
            isLoading = false
            return
        }

        if isLoading, loadingPath == path, !force { return }

        requestGeneration += 1
        let generation = requestGeneration
        loadingPath = path
        isLoading = true
        errorMessage = nil

        do {
            async let loadedStatus = git.getStatus(path: path)
            async let loadedCommits = git.getLog(path: path, count: 50, branch: nil, file: nil)
            let resolvedStatus = try await loadedStatus
            guard generation == requestGeneration else { return }
            status = resolvedStatus
            let resolvedCommits = try await loadedCommits
            guard generation == requestGeneration else { return }
            commits = resolvedCommits
        } catch {
            guard generation == requestGeneration else { return }
            errorMessage = error.localizedDescription
        }

        guard generation == requestGeneration else { return }
        isLoading = false
        loadingPath = nil
    }
}
