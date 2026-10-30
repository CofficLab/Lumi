import Foundation
@preconcurrency import LibGit2Swift
import ProviderGit

/// `GitBranchManaging` 契约的 libgit2 实现。
///
/// 复用 ``GitService`` 的串行域（按仓库根隔离）与 ``GitAsyncBridge`` 的
/// 超时保护，保证分支切换等写操作与其它 Git 读操作不会并发访问 libgit2。
///
/// 判定「是否 Git 仓库」刻意**不**调用 libgit2：纯文件系统向上查找 `.git`
/// 既更快，也避免 libgit2 打开不存在路径时的进程级风险（见
/// ``GitService/performOnGitQueue`` 的注释）。
public final class GitBranchProvider: GitBranchManaging, @unchecked Sendable {
    public init() {}

    // MARK: - GitBranchManaging

    public func isRepository(atPath path: String) async -> Bool {
        Self.repositoryRoot(containing: path) != nil
    }

    public func currentBranch(atPath path: String) async throws -> String? {
        let repoPath = try Self.requireRepositoryRoot(containing: path)
        return try await perform(repoPath: repoPath) {
            try? LibGit2.getCurrentBranch(at: repoPath)
        }
    }

    public func listBranches(atPath path: String, includeRemote: Bool) async throws -> [GitBranchInfo] {
        let repoPath = try Self.requireRepositoryRoot(containing: path)
        // 在并发域内就完成 `LibGit2Swift.GitBranch` → `GitBranchInfo` 的映射：
        // 前者不是 Sendable，不能跨并发边界传递。
        let locals = try await perform(repoPath: repoPath) {
            try LibGit2.getLocalBranches(at: repoPath).map { branch in
                GitBranchInfo(
                    name: branch.name,
                    isCurrent: branch.isCurrent,
                    isRemote: false,
                    upstream: branch.upstream
                )
            }
        }
        guard includeRemote else { return locals }

        let remotes = (try? await perform(repoPath: repoPath) {
            try LibGit2.getRemoteBranches(at: repoPath).map { branch in
                GitBranchInfo(
                    name: branch.name,
                    isCurrent: false,
                    isRemote: true,
                    upstream: nil
                )
            }
        }) ?? []

        // 远程分支与同名本地分支重复时只保留本地项。
        let localNames = Set(locals.map(\.name))
        return locals + remotes.filter { !localNames.contains($0.name) }
    }

    public func checkout(branch: String, atPath path: String) async throws {
        let repoPath = try Self.requireRepositoryRoot(containing: path)
        do {
            try await perform(repoPath: repoPath) {
                try LibGit2.checkout(branch: branch, at: repoPath)
            }
        } catch {
            throw GitBranchError.checkoutFailed(Self.describe(error))
        }
    }

    public func createBranch(named name: String, atPath path: String) async throws {
        let repoPath = try Self.requireRepositoryRoot(containing: path)
        do {
            try GitBranchService.validateBranchName(name)
        } catch {
            throw GitBranchError.invalidBranchName(Self.describe(error))
        }
        do {
            try await perform(repoPath: repoPath) {
                try LibGit2.checkoutNewBranch(named: name, at: repoPath)
            }
        } catch {
            throw GitBranchError.createFailed(Self.describe(error))
        }
    }

    // MARK: - 私有方法

    /// 在仓库对应的串行域上执行 libgit2 调用。
    private func perform<T: Sendable>(
        repoPath: String,
        body: @escaping @Sendable () throws -> T
    ) async throws -> T {
        try await GitAsyncBridge.perform(on: GitService.gitQueue(for: repoPath)) {
            try body()
        }
    }

    /// 向上查找 `.git` 判定仓库根；非仓库返回 `nil`。
    ///
    /// 纯文件系统实现，兼顾「目录型 `.git`」与「worktree 的 `.git` 文件」。
    static func repositoryRoot(containing path: String) -> String? {
        let expanded = (path as NSString).expandingTildeInPath
        var candidate = expanded
        // 路径不存在时退到其父目录，避免把「文件路径」当成目录。
        var isDirectory: ObjCBool = false
        if !FileManager.default.fileExists(atPath: candidate, isDirectory: &isDirectory) {
            candidate = URL(fileURLWithPath: candidate).deletingLastPathComponent().path
        } else if !isDirectory.boolValue {
            candidate = URL(fileURLWithPath: candidate).deletingLastPathComponent().path
        }

        for _ in 0..<128 {
            let dotGit = URL(fileURLWithPath: candidate).appendingPathComponent(".git").path
            if FileManager.default.fileExists(atPath: dotGit) {
                return candidate
            }
            let parent = URL(fileURLWithPath: candidate).deletingLastPathComponent().path
            guard parent != candidate else { return nil }
            candidate = parent
        }
        return nil
    }

    private static func requireRepositoryRoot(containing path: String) throws -> String {
        guard let root = repositoryRoot(containing: path) else {
            throw GitBranchError.notARepository(path: path)
        }
        return root
    }

    private static func describe(_ error: any Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
