import Foundation
import KitShell

/// Git LFS（大文件存储）相关服务。
///
/// LFS 没有纳入 LibGit2 绑定（libgit2 不包含 LFS 协议实现），
/// 因此这里通过 `git lfs` 子命令调用。
public enum GitLFSService {

    /// 当前仓库是否启用了 LFS。
    public static func isEnabled(at path: String) async -> Bool {
        let result = try? await ShellExecutor.execute(
            "git lfs version",
            options: ShellOptions(workingDirectory: path, throwsOnError: false)
        )
        return result?.isSuccess ?? false
            && (result?.stdout.contains("git-lfs") ?? false)
    }

    /// 列出受 LFS 跟踪的文件（每行一个）。
    public static func listTracked(at path: String) async -> [LFSFile] {
        let result = try? await ShellExecutor.execute(
            "git lfs ls-files -l",
            options: ShellOptions(workingDirectory: path, throwsOnError: false)
        )
        guard let stdout = result?.stdout, !stdout.isEmpty else { return [] }
        // 格式: <oid> * <path>
        return stdout
            .split(whereSeparator: \.isNewline)
            .compactMap { line -> LFSFile? in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return nil }
                // 例如: abc1234 * path/to/file.bin
                let parts = trimmed.split(separator: " ", maxSplits: 1,
                                          omittingEmptySubsequences: true).map(String.init)
                let oid = parts.first ?? ""
                let filePath = parts.count > 1
                    ? parts[1].replacingOccurrences(of: "* ", with: "")
                    : ""
                return LFSFile(oid: oid, path: filePath, raw: trimmed)
            }
    }

    /// 安装 LFS 钩子（`git lfs install`）。
    @discardableResult
    public static func install(at path: String) async throws -> String {
        let result = try await ShellExecutor.execute(
            "git lfs install",
            options: ShellOptions(workingDirectory: path)
        )
        return result.stdout
    }

    /// 拉取 LFS 对象（`git lfs fetch` / `pull`）。
    @discardableResult
    public static func fetch(at path: String) async throws -> String {
        let result = try await ShellExecutor.execute(
            "git lfs fetch",
            options: ShellOptions(workingDirectory: path, timeout: 120)
        )
        return result.stdout
    }

    /// 清理本地未引用的 LFS 缓存。
    @discardableResult
    public static func prune(at path: String) async throws -> String {
        let result = try await ShellExecutor.execute(
            "git lfs prune",
            options: ShellOptions(workingDirectory: path, timeout: 120)
        )
        return result.stdout
    }

    /// 添加跟踪规则（`git lfs track "<pattern>"`）。
    @discardableResult
    public static func track(_ pattern: String, at path: String) async throws -> String {
        let escaped = pattern.replacingOccurrences(of: "\"", with: "\\\"")
        let result = try await ShellExecutor.execute(
            "git lfs track \"\(escaped)\"",
            options: ShellOptions(workingDirectory: path)
        )
        return result.stdout
    }
}

public struct LFSFile: Identifiable, Hashable, Sendable {
    public let oid: String
    public let path: String
    public let raw: String
    public var id: String { path.isEmpty ? oid : path }
}
