import Foundation
import LibGit2Swift
import ShellKit

/// 合并冲突检测与解决服务。
///
/// libgit2 本身不暴露「按路径查询未合并」API，因此冲突文件列表
/// 通过 `git status --porcelain` 解析得到；解决动作则执行 git CLI：
///   - `git checkout --ours <file>`
///   - `git checkout --theirs <file>`
///   - `git add <file>`
public enum GitConflictService {

    public struct Conflict: Identifiable, Hashable, Sendable {
        public enum Resolution: String, Sendable, Hashable {
            case ours
            case theirs
            case manual
        }
        public let path: String
        public var resolution: Resolution = .manual
        public var id: String { path }
    }

    public static func hasConflicts(at path: String) -> Bool {
        // 同步入口仅占位；具体冲突检测由 listConflicts(at:) 异步完成。
        false
    }

    /// 列出所有未合并文件路径。
    public static func listConflicts(at path: String) async -> [Conflict] {
        let result = try? await ShellExecutor.execute(
            "git status --porcelain --unmerged",
            options: ShellOptions(workingDirectory: path, throwsOnError: false)
        )
        guard let stdout = result?.stdout else { return [] }
        var paths = Set<String>()
        for line in stdout.split(whereSeparator: \.isNewline) {
            // 格式: "XY <path>" — XY 是两位状态码
            // 未合并条目以 UU / AA / DD / AU / UA / DU / UD 开头
            guard line.count >= 3 else { continue }
            let xy = line.prefix(2)
            let unmergedCodes: Set<String> = ["UU", "AA", "DD", "AU", "UA", "DU", "UD"]
            guard unmergedCodes.contains(String(xy)) else { continue }
            let rest = line.dropFirst(3) // 跳过 "XY "
            let trimmed = rest.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty { paths.insert(trimmed) }
        }
        return paths.sorted().map { Conflict(path: $0) }
    }

    /// 保留当前分支版本（`git checkout --ours <path>`）。
    public static func resolveWithOurs(_ file: String, at path: String) async throws {
        let escaped = shellEscape(file)
        _ = try await ShellExecutor.execute(
            "git checkout --ours -- \(escaped)",
            options: ShellOptions(workingDirectory: path)
        )
        // 标记为已解决
        _ = try? await ShellExecutor.execute(
            "git add -- \(escaped)",
            options: ShellOptions(workingDirectory: path, throwsOnError: false)
        )
    }

    /// 采用对方版本（`git checkout --theirs <path>`）。
    public static func resolveWithTheirs(_ file: String, at path: String) async throws {
        let escaped = shellEscape(file)
        _ = try await ShellExecutor.execute(
            "git checkout --theirs -- \(escaped)",
            options: ShellOptions(workingDirectory: path)
        )
        _ = try? await ShellExecutor.execute(
            "git add -- \(escaped)",
            options: ShellOptions(workingDirectory: path, throwsOnError: false)
        )
    }

    /// 标记文件为已解决（不修改内容）。
    public static func markResolved(_ file: String, at path: String) async throws {
        let escaped = shellEscape(file)
        _ = try await ShellExecutor.execute(
            "git add -- \(escaped)",
            options: ShellOptions(workingDirectory: path)
        )
    }

    /// 放弃合并（`git merge --abort`）。
    public static func abortMerge(at path: String) async throws {
        _ = try await ShellExecutor.execute(
            "git merge --abort",
            options: ShellOptions(workingDirectory: path, throwsOnError: false)
        )
    }

    /// 继续合并（解决完所有冲突后，提交合并）。
    public static func continueMerge(message: String?, at path: String) async throws {
        let msg = (message?.isEmpty == false ? message : "Merge branch")!
        let escaped = shellEscape(msg)
        _ = try await ShellExecutor.execute(
            "git commit --no-edit -m \(escaped)",
            options: ShellOptions(workingDirectory: path, throwsOnError: false)
        )
    }

    // MARK: - helpers

    private static func shellEscape(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
