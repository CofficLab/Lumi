import EditorContracts
import Foundation
import ShellKit

// MARK: - SCM 中立契约适配器（Phase 7 §15.6）
//
// GitPlugin 对 `SourceControlProviding` 的实现：编辑器侧消费者
// （Diff 基线、gutter、blame）只经 kernel 服务注册表取得本能力，
// Git 不再是编辑器侧的私有依赖。discovery/status/baseline 复用
// GitService（libgit2）；stage/unstage 走 git CLI（与冲突服务同管道）。

@MainActor
public final class GitSourceControlAdapter: SourceControlProviding {
    public init() {}

    public func repositoryRoot(for uri: URL) -> URL? {
        guard let root = try? GitService.repositoryRoot(containing: uri.path) else { return nil }
        return URL(fileURLWithPath: root)
    }

    public func status(for uri: URL) async -> EditorSCMStatus {
        guard let root = repositoryRoot(for: uri) else { return .none }
        let rootPath = root.path

        // 变更列表（staged 优先合并去重）+ GitStatus.staged 判定暂存位。
        guard let files = try? await GitService.shared.getUncommittedChanges(path: rootPath) else {
            return EditorSCMStatus(repositoryRoot: root, changes: [])
        }
        let stagedSet: Set<String>
        if let gitStatus = try? await GitService.shared.getStatus(path: rootPath) {
            stagedSet = Set(gitStatus.staged)
        } else {
            stagedSet = []
        }
        let conflictedPaths: Set<String> = await GitConflictService.listConflicts(at: rootPath)
            .map(\.path)
            .reduce(into: []) { $0.insert($1) }

        let changes = files.map { file -> EditorSCMChange in
            let fileURI = root.appendingPathComponent(file.path)
            let state: EditorSCMChange.State
            if conflictedPaths.contains(file.path) {
                state = .conflicted
            } else {
                state = Self.mapChangeType(file.changeType)
            }
            return EditorSCMChange(
                uri: fileURI,
                state: state,
                isStaged: stagedSet.contains(file.path)
            )
        }
        return EditorSCMStatus(repositoryRoot: root, changes: changes)
    }

    public func baselineContent(of uri: URL) async -> String? {
        guard let root = repositoryRoot(for: uri) else { return nil }
        let relative = Self.relativePath(of: uri, in: root)
        guard let (before, _) = try? await GitService.shared.getUncommittedFileContentChange(
            path: root.path,
            file: relative
        ) else { return nil }
        return before
    }

    public func stage(uris: [URL]) async throws {
        try await runGit(pathArguments: uris, subcommand: "add")
    }

    public func unstage(uris: [URL]) async throws {
        try await runGit(pathArguments: uris, subcommand: "reset")
    }

    public func commit(message: String, in repository: URL, uris: [URL]?) async throws {
        // 指定文件时先暂存（保持「所见即所提交」语义）。
        if let uris, !uris.isEmpty {
            try await stage(uris: uris)
        }
        _ = try await ShellExecutor.execute(
            "git commit -m \(Self.shellEscape(message))",
            options: ShellOptions(workingDirectory: repository.path)
        )
    }

    // MARK: - Private

    private func runGit(pathArguments: [URL], subcommand: String) async throws {
        guard !pathArguments.isEmpty else { return }
        // 同仓库分组执行（跨仓库文件分别处理）。
        var byRoot: [URL: [String]] = [:]
        for uri in pathArguments {
            guard let root = repositoryRoot(for: uri) else { continue }
            byRoot[root, default: []].append(Self.shellEscape(Self.relativePath(of: uri, in: root)))
        }
        for (root, escapedPaths) in byRoot {
            _ = try await ShellExecutor.execute(
                "git \(subcommand) -- \(escapedPaths.joined(separator: " "))",
                options: ShellOptions(workingDirectory: root.path)
            )
        }
    }

    private static func relativePath(of uri: URL, in root: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let filePath = uri.standardizedFileURL.path
        guard filePath.hasPrefix(rootPath + "/") else { return filePath }
        return String(filePath.dropFirst(rootPath.count + 1))
    }

    private static func mapChangeType(_ type: GitChangeType) -> EditorSCMChange.State {
        switch type {
        case .modified: return .modified
        case .added: return .added
        case .deleted: return .deleted
        case .renamed: return .renamed
        case .untracked: return .untracked
        }
    }

    private static func shellEscape(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

enum GitSourceControlError: Error {
    case noRepository
}
